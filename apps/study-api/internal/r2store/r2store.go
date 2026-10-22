// r2store - the lesson blob home on Cloudflare R2 (founder 2026-10-17,
// "how do we move to cloudflare r2").
//
// A deliberately small S3-compatible client: SigV4 signing with the
// stdlib only (the module stays lean - no aws-sdk-go-v2), exactly the
// operations the lesson cache needs (GET, PUT, HEAD, LIST) and nothing
// else. Cloudflare R2 is wire-compatible with S3: the endpoint is
// https://<account_id>.r2.cloudflarestorage.com, path-style addressing,
// credential scope region "auto", service "s3".
//
// Why a bucket under the lesson cache at all: learn.lessons rides the
// InsForge cache database under a hard storage ceiling (~430 MB free /
// 1 GB paid tier) while every deep lesson carries 10 long note parts
// plus 20 quiz items. R2's free tier holds 10 GB with ZERO egress
// fees, reads are effectively free (10M Class B ops a month), and the
// runtime below spends one Class A PUT per generated lesson - orders
// of magnitude under the 1M Class A budget.
//
// Posture (the zero-risk cut): the bucket is the DURABLE home, the
// cache database stays the INDEX. Reads go R2-first and fall back to
// the database; writes are dual (bucket + database). Unset the R2_*
// environment and every path behaves exactly as before.
package r2store

import (
        "bytes"
        "context"
        "crypto/hmac"
        "crypto/sha256"
        "encoding/hex"
        "encoding/xml"
        "errors"
        "fmt"
        "io"
        "log/slog"
        "net/http"
        "net/url"
        "os"
        "sort"
        "strings"
        "sync"
        "sync/atomic"
        "time"
)

// Empty payload SHA-256 (the hex digest of the empty string) - the
// x-amz-content-sha256 value for GET / HEAD / LIST requests.
const emptyPayloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

// oversizeWarnBytes flags lesson payloads far past the ~40 KB norm
// (1 MiB) on the write path. A twelve megabyte object in a bucket
// full of small documents is a content bug worth one log line.
const oversizeWarnBytes = 1 << 20

// Client is the lesson-blob surface over one R2 bucket. Build with
// FromEnv; FromEnv returns nil when R2 is not configured, and every
// consumer treats nil as "bucket off".
type Client struct {
        endpoint  string // https://<account_id>.r2.cloudflarestorage.com
        bucket    string
        accessKey string
        secretKey string
        prefix    string // "lessons/" by default; objects ride prefix + topicID + .json
        http      *http.Client
        log       *slog.Logger

        // packMemo caches decoded pack shards (see packs.go). Class B is
        // free, so this is latency sugar with a hard forget-all bound.
        packMemo  sync.Map
        packMemoN atomic.Int64
}

// FromEnv builds the client from the environment, or returns nil when
// R2 is not configured (the R2-off posture). Required variables:
//
//      R2_ACCOUNT_ID      the Cloudflare account id (or R2_ENDPOINT for a full override)
//      R2_BUCKET          the bucket name (e.g. renance-lessons)
//      R2_ACCESS_KEY_ID   from "Manage R2 API Tokens" (Object Read & Write)
//      R2_SECRET_ACCESS_KEY
//
// Optional:
//
//      R2_PREFIX          object key prefix (default "lessons/")
func FromEnv(log *slog.Logger) *Client {
        account := strings.TrimSpace(os.Getenv("R2_ACCOUNT_ID"))
        bucket := strings.TrimSpace(os.Getenv("R2_BUCKET"))
        access := strings.TrimSpace(os.Getenv("R2_ACCESS_KEY_ID"))
        secret := strings.TrimSpace(os.Getenv("R2_SECRET_ACCESS_KEY"))
        if account == "" || bucket == "" || access == "" || secret == "" {
                return nil
        }
        endpoint := strings.TrimSpace(os.Getenv("R2_ENDPOINT"))
        if endpoint == "" {
                endpoint = fmt.Sprintf("https://%s.r2.cloudflarestorage.com", account)
        }
        endpoint = strings.TrimSuffix(endpoint, "/")
        prefix := strings.TrimSpace(os.Getenv("R2_PREFIX"))
        if prefix == "" {
                prefix = "lessons/"
        }
        if !strings.HasSuffix(prefix, "/") {
                prefix += "/"
        }
        if log == nil {
                log = slog.Default()
        }
        return &Client{
                endpoint:  endpoint,
                bucket:    bucket,
                accessKey: access,
                secretKey: secret,
                prefix:    prefix,
                http:      &http.Client{Timeout: 30 * time.Second},
                log:       log,
        }
}

// Prefix reports the object key prefix lesson objects live under.
func (c *Client) Prefix() string { return c.prefix }

// FromEnvPrefix builds a second client over the SAME bucket with a
// different folder (founder 2026-10-22: profile pictures live under
// profile-picture/ while lessons keep lessons/). One credential set,
// two logical folders, zero extra configuration.
func FromEnvPrefix(log *slog.Logger, prefix string) *Client {
        account := strings.TrimSpace(os.Getenv("R2_ACCOUNT_ID"))
        bucket := strings.TrimSpace(os.Getenv("R2_BUCKET"))
        access := strings.TrimSpace(os.Getenv("R2_ACCESS_KEY_ID"))
        secret := strings.TrimSpace(os.Getenv("R2_SECRET_ACCESS_KEY"))
        if account == "" || bucket == "" || access == "" || secret == "" {
                return nil
        }
        endpoint := strings.TrimSpace(os.Getenv("R2_ENDPOINT"))
        if endpoint == "" {
                endpoint = fmt.Sprintf("https://%s.r2.cloudflarestorage.com", account)
        }
        endpoint = strings.TrimSuffix(endpoint, "/")
        prefix = strings.TrimSpace(prefix)
        if prefix == "" {
                prefix = "lessons/"
        }
        if !strings.HasSuffix(prefix, "/") {
                prefix += "/"
        }
        if log == nil {
                log = slog.Default()
        }
        return &Client{
                endpoint:  endpoint,
                bucket:    bucket,
                accessKey: access,
                secretKey: secret,
                prefix:    prefix,
                http:      &http.Client{Timeout: 30 * time.Second},
                log:       log,
        }
}

// PutObject stores one raw object under the client's prefix with an
// explicit content type (the lesson Put is json-only; photos are not).
func (c *Client) PutObject(ctx context.Context, key, contentType string, payload []byte) error {
        if c == nil {
                return errors.New("r2store: client not configured")
        }
        sum := sha256.Sum256(payload)
        status, body, err := c.roundTrip(ctx, http.MethodPut, contentType, payload, hex.EncodeToString(sum[:]), nil, c.prefix+key)
        if err != nil {
                return err
        }
        if status != http.StatusOK {
                return fmt.Errorf("r2store: put object %s: status %d: %s", key, status, snippet(body))
        }
        return nil
}

// GetObject reads one raw object under the client's prefix (no pack
// tier - plain GET, ok=false on 404).
func (c *Client) GetObject(ctx context.Context, key string) (payload []byte, ok bool, err error) {
        if c == nil {
                return nil, false, errors.New("r2store: client not configured")
        }
        status, body, err := c.roundTrip(ctx, http.MethodGet, "", nil, "", nil, c.prefix+key)
        if err != nil {
                return nil, false, err
        }
        if status == http.StatusNotFound {
                return nil, false, nil
        }
        if status != http.StatusOK {
                return nil, false, fmt.Errorf("r2store: get object %s: status %d: %s", key, status, snippet(body))
        }
        return body, true, nil
}

// DeleteObject removes one raw object under the client's prefix. A 404
// counts as success - the object is gone either way.
func (c *Client) DeleteObject(ctx context.Context, key string) error {
        if c == nil {
                return errors.New("r2store: client not configured")
        }
        status, body, err := c.roundTrip(ctx, http.MethodDelete, "", nil, "", nil, c.prefix+key)
        if err != nil {
                return err
        }
        if status != http.StatusNoContent && status != http.StatusOK && status != http.StatusNotFound {
                return fmt.Errorf("r2store: delete object %s: status %d: %s", key, status, snippet(body))
        }
        return nil
}

// Bucket reports the configured bucket name (boot logs only - it is
// not a secret).
func (c *Client) Bucket() string { return c.bucket }

// ─── Lesson-keyed surface (satisfies learn.LessonBlobs) ──────────────────

func (c *Client) lessonKey(topicID string) string {
        return c.prefix + sanitizeKey(topicID) + ".json"
}

// sanitizeKey keeps topic ids URL- and S3-safe: anything outside the
// slug alphabet becomes a dash. Topic ids are already slugs; this is
// the belt over the braces.
func sanitizeKey(topicID string) string {
        var b strings.Builder
        n := 0
        for _, r := range strings.TrimSpace(topicID) {
                if n >= 160 {
                        break
                }
                switch {
                case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-', r == '_', r == '.':
                        b.WriteRune(r)
                default:
                        b.WriteByte('-')
                }
                n++
        }
        return b.String()
}

// Get fetches one lesson blob by topic id. ok=false with a nil error
// is a clean miss (the object does not exist) - the caller falls
// through to the next tier.
//
// Read order: the per topic key first (one Class B GET), then the
// topic's pack shard (packs.go, one more Class B GET). Both are free
// reads; the pack tier is what lets a 1.3M topic archive ride 60k
// objects instead of 1.3M.
func (c *Client) Get(ctx context.Context, topicID string) (payload []byte, ok bool, err error) {
        if c == nil {
                return nil, false, errors.New("r2store: client not configured")
        }
        status, body, err := c.roundTrip(ctx, http.MethodGet, "", nil, "", nil, c.lessonKey(topicID))
        if err != nil {
                return nil, false, err
        }
        if status == http.StatusNotFound {
                if lessons, packed := c.packLessons(ctx, topicID); packed {
                        if raw, found := lessons[topicID]; found && len(raw) > 0 {
                                return raw, true, nil
                        }
                }
                return nil, false, nil
        }
        if status != http.StatusOK {
                return nil, false, fmt.Errorf("r2store: get %s: status %d: %s", topicID, status, snippet(body))
        }
        return body, true, nil
}

// Put stores one lesson blob (content-type application/json). One
// Class A operation per generated lesson - nothing else writes.
//
// An oversize payload is logged so the whale is visible: a lesson
// far past the ~40 KB norm means something bloated the document and
// every upload of it drags megabytes through the write budget.
func (c *Client) Put(ctx context.Context, topicID string, payload []byte) error {
        if c == nil {
                return errors.New("r2store: client not configured")
        }
        if len(payload) > oversizeWarnBytes && c.log != nil {
                c.log.Warn("r2store: oversize lesson payload on the write path",
                        "topic", topicID, "bytes", len(payload))
        }
        sum := sha256.Sum256(payload)
        status, body, err := c.roundTrip(ctx, http.MethodPut, "application/json", payload, hex.EncodeToString(sum[:]), nil, c.lessonKey(topicID))
        if err != nil {
                return err
        }
        if status != http.StatusOK {
                return fmt.Errorf("r2store: put %s: status %d: %s", topicID, status, snippet(body))
        }
        return nil
}

// Has probes which of the topic ids already hold a bucket object, via
// one HEAD per id (Class B reads - effectively free) with a small
// concurrency cap. Missing ids are simply absent from the map.
func (c *Client) Has(ctx context.Context, topicIDs []string) (map[string]bool, error) {
        if c == nil {
                return nil, errors.New("r2store: client not configured")
        }
        out := map[string]bool{}
        const lanes = 4
        sem := make(chan struct{}, lanes)
        var mu sync.Mutex
        var wg sync.WaitGroup
        for _, id := range topicIDs {
                if id == "" {
                        continue
                }
                wg.Add(1)
                go func(id string) {
                        defer wg.Done()
                        sem <- struct{}{}
                        defer func() { <-sem }()
                        status, _, err := c.roundTrip(ctx, http.MethodHead, "", nil, "", nil, c.lessonKey(id))
                        if err == nil && status == http.StatusOK {
                                mu.Lock()
                                out[id] = true
                                mu.Unlock()
                        }
                }(id)
        }
        wg.Wait()
        return out, nil
}

// ListLessons enumerates every lesson object under the prefix as
// topicID -> object size in bytes (paginated ListObjectsV2, one page
// per 1000 keys).
func (c *Client) ListLessons(ctx context.Context) (map[string]int64, error) {
        out := map[string]int64{}
        token := ""
        for {
                q := []kv{
                        {"list-type", "2"},
                        {"max-keys", "1000"},
                        {"prefix", c.prefix},
                }
                if token != "" {
                        q = append(q, kv{"continuation-token", token})
                }
                status, body, err := c.roundTrip(ctx, http.MethodGet, "", nil, "", q, "")
                if err != nil {
                        return nil, err
                }
                if status != http.StatusOK {
                        return nil, fmt.Errorf("r2store: list: status %d: %s", status, snippet(body))
                }
                var page struct {
                        IsTruncated bool   `xml:"IsTruncated"`
                        NextToken   string `xml:"NextContinuationToken"`
                        Contents    []struct {
                                Key  string `xml:"Key"`
                                Size int64  `xml:"Size"`
                        } `xml:"Contents"`
                }
                if err := xml.Unmarshal(body, &page); err != nil {
                        return nil, fmt.Errorf("r2store: list: %w", err)
                }
                for _, o := range page.Contents {
                        if !strings.HasPrefix(o.Key, c.prefix) || !strings.HasSuffix(o.Key, ".json") {
                                continue
                        }
                        id := strings.TrimSuffix(strings.TrimPrefix(o.Key, c.prefix), ".json")
                        if id != "" {
                                out[id] = o.Size
                        }
                }
                if !page.IsTruncated || page.NextToken == "" {
                        return out, nil
                }
                token = page.NextToken
        }
}

// ─── Signed transport ────────────────────────────────────────────────────

// roundTrip signs and sends one request. When key is empty the request
// addresses the bucket root (the LIST call); the query is built from
// the sorted kv pairs - the same encoding feeds both the wire URL and
// the canonical request, so signature and request can never disagree.
// payloadHash empty means the empty-payload hash (GET / HEAD / LIST);
// PUT always computes and passes the real body digest.
func (c *Client) roundTrip(ctx context.Context, method, contentType string, body []byte, payloadHash string, q []kv, key string) (int, []byte, error) {
        if c == nil {
                return 0, nil, errors.New("r2store: client not configured")
        }
        if payloadHash == "" {
                payloadHash = emptyPayloadHash
        }
        path := "/" + c.bucket
        if key != "" {
                path += "/" + awsEscapePath(key)
        }
        query := canonicalQuery(q)
        full := c.endpoint + path
        if query != "" {
                full += "?" + query
        }
        var bodyReader io.Reader
        if body != nil {
                bodyReader = bytes.NewReader(body)
        }
        req, err := http.NewRequestWithContext(ctx, method, full, bodyReader)
        if err != nil {
                return 0, nil, fmt.Errorf("r2store: %w", err)
        }
        if body != nil {
                req.ContentLength = int64(len(body))
        }
        if contentType != "" {
                req.Header.Set("Content-Type", contentType)
        }
        c.sign(req, payloadHash)

        resp, err := c.http.Do(req)
        if err != nil {
                return 0, nil, fmt.Errorf("r2store: %s %s: %w", method, path, err)
        }
        defer resp.Body.Close()
        rbody, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
        if err != nil {
                return resp.StatusCode, nil, fmt.Errorf("r2store: %s %s: read body: %w", method, path, err)
        }
        return resp.StatusCode, rbody, nil
}

// sign applies AWS Signature Version 4 to the request (signed headers:
// host, x-amz-content-sha256, x-amz-date - the minimum R2 requires).
func (c *Client) sign(req *http.Request, payloadHash string) {
        now := time.Now().UTC()
        amzDate := now.Format("20060102T150405Z")
        dateStamp := now.Format("20060102")

        signedHeaders := "host;x-amz-content-sha256;x-amz-date"
        canonicalHeaders := "host:" + req.URL.Host + "\n" +
                "x-amz-content-sha256:" + payloadHash + "\n" +
                "x-amz-date:" + amzDate + "\n"

        canonicalRequest := strings.Join([]string{
                req.Method,
                escapedPathOf(req.URL),
                req.URL.RawQuery,
                canonicalHeaders,
                signedHeaders,
                payloadHash,
        }, "\n")

        crSum := sha256.Sum256([]byte(canonicalRequest))
        scope := dateStamp + "/auto/s3/aws4_request"
        stringToSign := strings.Join([]string{
                "AWS4-HMAC-SHA256",
                amzDate,
                scope,
                hex.EncodeToString(crSum[:]),
        }, "\n")

        kDate := hmacSHA256([]byte("AWS4"+c.secretKey), dateStamp)
        kRegion := hmacSHA256(kDate, "auto")
        kService := hmacSHA256(kRegion, "s3")
        kSigning := hmacSHA256(kService, "aws4_request")
        signature := hex.EncodeToString(hmacSHA256(kSigning, stringToSign))

        req.Header.Set("Host", req.URL.Host)
        req.Header.Set("X-Amz-Date", amzDate)
        req.Header.Set("X-Amz-Content-Sha256", payloadHash)
        req.Header.Set("Authorization",
                "AWS4-HMAC-SHA256 Credential="+c.accessKey+"/"+scope+
                        ", SignedHeaders="+signedHeaders+", Signature="+signature)
}

func hmacSHA256(key []byte, data string) []byte {
        h := hmac.New(sha256.New, key)
        h.Write([]byte(data))
        return h.Sum(nil)
}

// ─── AWS canonical encoding ──────────────────────────────────────────────

type kv struct{ k, v string }

// awsEscape percent-encodes everything outside the AWS unreserved set
// (A-Za-z0-9 - . _ ~), uppercase hex - the SigV4 rule, which is also
// the correct wire encoding for the query and path here.
func awsEscape(s string) string {
        var b strings.Builder
        for i := 0; i < len(s); i++ {
                ch := s[i]
                if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') ||
                        ch == '-' || ch == '.' || ch == '_' || ch == '~' {
                        b.WriteByte(ch)
                } else {
                        fmt.Fprintf(&b, "%%%02X", ch)
                }
        }
        return b.String()
}

func awsEscapePath(p string) string {
        parts := strings.Split(p, "/")
        for i, part := range parts {
                parts[i] = awsEscape(part)
        }
        return strings.Join(parts, "/")
}

// canonicalQuery renders the kv pairs sorted by key (SigV4 requires
// lexicographic order) with escaped values.
func canonicalQuery(q []kv) string {
        if len(q) == 0 {
                return ""
        }
        sorted := make([]kv, len(q))
        copy(sorted, q)
        sort.Slice(sorted, func(i, j int) bool {
                if sorted[i].k != sorted[j].k {
                        return sorted[i].k < sorted[j].k
                }
                return sorted[i].v < sorted[j].v
        })
        parts := make([]string, 0, len(sorted))
        for _, p := range sorted {
                parts = append(parts, awsEscape(p.k)+"="+awsEscape(p.v))
        }
        return strings.Join(parts, "&")
}

// escapedPathOf returns the request path exactly as it will travel on
// the wire (RawPath when the URL carries one, else the escaped Path).
func escapedPathOf(u *url.URL) string {
        if u.RawPath != "" {
                return u.RawPath
        }
        return awsEscapePath(u.Path)
}

func snippet(b []byte) string {
        s := strings.TrimSpace(string(b))
        if len(s) > 200 {
                s = s[:200] + "..."
        }
        return s
}
