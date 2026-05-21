CREATE TYPE "public"."rappel_recurrence_type" AS ENUM('daily');--> statement-breakpoint
CREATE TABLE "rappels" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"officine_id" uuid,
	"boite_id" uuid,
	"label" text NOT NULL,
	"heure" time NOT NULL,
	"recurrence_type" "rappel_recurrence_type" DEFAULT 'daily' NOT NULL,
	"actif" boolean DEFAULT true NOT NULL,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "rappels" ADD CONSTRAINT "rappels_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "rappels" ADD CONSTRAINT "rappels_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "rappels" ADD CONSTRAINT "rappels_boite_id_boites_id_fk" FOREIGN KEY ("boite_id") REFERENCES "public"."boites"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_rappels_user_actif" ON "rappels" USING btree ("user_id","actif");