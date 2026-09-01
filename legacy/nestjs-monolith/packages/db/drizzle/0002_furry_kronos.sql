CREATE TYPE "core"."verification_status" AS ENUM('draft', 'pending', 'verified', 'rejected');--> statement-breakpoint
ALTER TABLE "core"."organizations" ADD COLUMN "verification_status" "core"."verification_status" DEFAULT 'draft' NOT NULL;--> statement-breakpoint
ALTER TABLE "core"."organizations" ADD COLUMN "verification_note" text;--> statement-breakpoint
ALTER TABLE "core"."organizations" ADD COLUMN "reviewed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "core"."organizations" ADD COLUMN "reviewed_by_id" uuid;--> statement-breakpoint
ALTER TABLE "core"."organizations" ADD CONSTRAINT "organizations_reviewed_by_id_users_id_fk" FOREIGN KEY ("reviewed_by_id") REFERENCES "core"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "organizations_verification_status_idx" ON "core"."organizations" USING btree ("verification_status");