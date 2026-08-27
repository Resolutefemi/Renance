CREATE TYPE "cbt"."attempt_status" AS ENUM('in_progress', 'graded');--> statement-breakpoint
CREATE TYPE "cbt"."bundle_status" AS ENUM('draft', 'published', 'archived');--> statement-breakpoint
CREATE TABLE "cbt"."attempts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"bundle_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"organization_id" uuid NOT NULL,
	"status" "cbt"."attempt_status" DEFAULT 'graded' NOT NULL,
	"answers" jsonb NOT NULL,
	"score" integer NOT NULL,
	"total_marks" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cbt"."bundles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organization_id" uuid NOT NULL,
	"code" text NOT NULL,
	"version" integer DEFAULT 1 NOT NULL,
	"title" text NOT NULL,
	"sha256" text NOT NULL,
	"question_count" integer NOT NULL,
	"total_marks" integer NOT NULL,
	"duration_minutes" integer,
	"payload" jsonb NOT NULL,
	"answer_key" jsonb NOT NULL,
	"status" "cbt"."bundle_status" DEFAULT 'published' NOT NULL,
	"created_by_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "cbt"."attempts" ADD CONSTRAINT "attempts_bundle_id_bundles_id_fk" FOREIGN KEY ("bundle_id") REFERENCES "cbt"."bundles"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cbt"."attempts" ADD CONSTRAINT "attempts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "core"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cbt"."attempts" ADD CONSTRAINT "attempts_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "core"."organizations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cbt"."bundles" ADD CONSTRAINT "bundles_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "core"."organizations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cbt"."bundles" ADD CONSTRAINT "bundles_created_by_id_users_id_fk" FOREIGN KEY ("created_by_id") REFERENCES "core"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "attempts_bundle_user_unique" ON "cbt"."attempts" USING btree ("bundle_id","user_id");--> statement-breakpoint
CREATE INDEX "attempts_user_idx" ON "cbt"."attempts" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "bundles_org_code_version_unique" ON "cbt"."bundles" USING btree ("organization_id","code","version");--> statement-breakpoint
CREATE INDEX "bundles_org_status_idx" ON "cbt"."bundles" USING btree ("organization_id","status");