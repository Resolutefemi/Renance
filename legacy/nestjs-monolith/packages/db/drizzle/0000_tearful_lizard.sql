CREATE SCHEMA "cbt";
--> statement-breakpoint
CREATE SCHEMA "core";
--> statement-breakpoint
CREATE SCHEMA "payroll";
--> statement-breakpoint
CREATE SCHEMA "school";
--> statement-breakpoint
CREATE SCHEMA "sme";
--> statement-breakpoint
CREATE SCHEMA "skills";
--> statement-breakpoint
CREATE SCHEMA "utilities";
--> statement-breakpoint
CREATE TYPE "core"."user_status" AS ENUM('active', 'suspended');--> statement-breakpoint
CREATE TABLE "core"."users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" "citext" NOT NULL,
	"password_hash" text NOT NULL,
	"display_name" text NOT NULL,
	"status" "core"."user_status" DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE INDEX "users_created_at_idx" ON "core"."users" USING btree ("created_at");