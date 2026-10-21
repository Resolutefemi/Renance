// r2store tests: the SigV4 signer produces the documented digest chain
// (the empty-payload hash and the canonical encodings are checked
// against known AWS values), the AWS escaping set holds, the
// lesson-key builder sanitizes hostile topic ids, and FromEnv stays
// nil until every required variable is present.
package r2store

import (
        "net/http/httptest"
        "strings"
        "testing"
)

func TestEmptyPayloadHash(t *testing.T) {
        // The SHA-256 of the empty string, straight from the AWS docs.
        const want = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        if emptyPayloadHash != want {
                t.Fatalf("empty payload hash drifted: got %s", emptyPayloadHash)
        }
}

func TestAwsEscape(t *testing.T) {
        // awsEscape is the STRICT escaper: it encodes every byte outside
        // the AWS unreserved set, slashes included. Query values and
        // individual path segments go through it; whole paths go through
        // awsEscapePath, which splits on "/" first.
        cases := []struct{ in, want string }{
                {"abc.json", "abc.json"},
                {"lessons/abc.json", "lessons%2Fabc.json"},
                {"a b", "a%20b"},
                {"a+b", "a%2Bb"},
                {"a~b-c_d.e", "a~b-c_d.e"},
                {"a=b&c", "a%3Db%26c"},
                {"ü", "%C3%BC"},
        }
        for _, c := range cases {
                if got := awsEscape(c.in); got != c.want {
                        t.Errorf("awsEscape(%q) = %q, want %q", c.in, got, c.want)
                }
        }
}

func TestAwsEscapePath(t *testing.T) {
        if got := awsEscapePath("lessons/a b/c.json"); got != "lessons/a%20b/c.json" {
                t.Fatalf("path escaping broke on spaces: %q", got)
        }
}

func TestCanonicalQuerySorts(t *testing.T) {
        got := canonicalQuery([]kv{{"list-type", "2"}, {"prefix", "lessons/"}, {"max-keys", "1000"}})
        want := "list-type=2&max-keys=1000&prefix=lessons%2F"
        if got != want {
                t.Fatalf("canonicalQuery = %q, want %q", got, want)
        }
        if got := canonicalQuery([]kv{{"continuation-token", "a/b+c"}, {"list-type", "2"}}); got != "continuation-token=a%2Fb%2Bc&list-type=2" {
                t.Fatalf("token encoding drifted: %q", got)
        }
}

func TestSanitizeKey(t *testing.T) {
        if got := sanitizeKey("jamb-chem-001"); got != "jamb-chem-001" {
                t.Fatalf("clean id mutated: %q", got)
        }
        if got := sanitizeKey("chm/101 hard:path?"); got != "chm-101-hard-path-" {
                t.Fatalf("hostile id not sanitized: %q", got)
        }
        long := strings.Repeat("x", 300)
        if got := sanitizeKey(long); len(got) != 160 {
                t.Fatalf("length cap ignored: %d", len(got))
        }
}

func TestLessonKey(t *testing.T) {
        c := &Client{prefix: "lessons/"}
        if got, want := c.lessonKey("abc-001"), "lessons/abc-001.json"; got != want {
                t.Fatalf("lessonKey = %q, want %q", got, want)
        }
}

func TestFromEnvGating(t *testing.T) {
        if FromEnv(nil) != nil {
                t.Fatal("FromEnv must be nil with no environment")
        }
        t.Setenv("R2_ACCOUNT_ID", "abc123")
        t.Setenv("R2_BUCKET", "renance-lessons")
        t.Setenv("R2_ACCESS_KEY_ID", "key")
        if FromEnv(nil) != nil {
                t.Fatal("FromEnv must be nil until every credential is set")
        }
        t.Setenv("R2_SECRET_ACCESS_KEY", "secret")
        c := FromEnv(nil)
        if c == nil {
                t.Fatal("FromEnv returned nil with a complete environment")
        }
        if c.endpoint != "https://abc123.r2.cloudflarestorage.com" {
                t.Fatalf("endpoint = %q", c.endpoint)
        }
        if c.prefix != "lessons/" {
                t.Fatalf("prefix = %q", c.prefix)
        }
        t.Setenv("R2_PREFIX", "deep/docs")
        if c2 := FromEnv(nil); c2.prefix != "deep/docs/" {
                t.Fatalf("custom prefix lost: %q", c2.prefix)
        }
        t.Setenv("R2_ENDPOINT", "https://custom.invalid/")
        if c3 := FromEnv(nil); c3.endpoint != "https://custom.invalid" {
                t.Fatalf("endpoint override lost: %q", c3.endpoint)
        }
}

func TestSignHeaders(t *testing.T) {
        c := &Client{endpoint: "https://abc123.r2.cloudflarestorage.com", bucket: "renance-lessons", accessKey: "AKID", secretKey: "secret"}
        req := httptest.NewRequest("GET", "https://abc123.r2.cloudflarestorage.com/renance-lessons/lessons/abc-001.json", nil)
        c.sign(req, emptyPayloadHash)
        auth := req.Header.Get("Authorization")
        if !strings.HasPrefix(auth, "AWS4-HMAC-SHA256 Credential=AKID/") {
                t.Fatalf("authorization missing credential: %q", auth)
        }
        if !strings.Contains(auth, "/auto/s3/aws4_request") {
                t.Fatalf("scope must pin region auto + service s3: %q", auth)
        }
        if !strings.Contains(auth, "SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=") {
                t.Fatalf("signed headers drift: %q", auth)
        }
        if got := req.Header.Get("X-Amz-Content-Sha256"); got != emptyPayloadHash {
                t.Fatalf("payload hash header = %q", got)
        }
        if req.Header.Get("X-Amz-Date") == "" {
                t.Fatal("x-amz-date missing")
        }
}

func TestNilClientFails(t *testing.T) {
        var c *Client
        if _, _, err := c.Get(t.Context(), "x"); err == nil {
                t.Fatal("nil client must fail loudly, not look like a miss")
        }
}
