CREATE TYPE "public"."type_compte" AS ENUM('particulier', 'pro');--> statement-breakpoint
CREATE TYPE "public"."type_officine" AS ENUM('perso', 'patient');--> statement-breakpoint
CREATE TYPE "public"."role_partage" AS ENUM('owner', 'editor', 'viewer');--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"password_hash" text NOT NULL,
	"email_verified_at" timestamp with time zone,
	"nom" text NOT NULL,
	"prenom" text NOT NULL,
	"type_compte" "type_compte" NOT NULL,
	"telephone" text,
	"preferences" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"last_login_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "officines" (
	"id" uuid PRIMARY KEY NOT NULL,
	"nom" text NOT NULL,
	"type" "type_officine" NOT NULL,
	"proprietaire_user_id" uuid NOT NULL,
	"date_naissance" date,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "partages" (
	"id" uuid PRIMARY KEY NOT NULL,
	"officine_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"role" "role_partage" NOT NULL,
	"invited_by" uuid,
	"invited_at" timestamp with time zone NOT NULL,
	"accepted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "officines" ADD CONSTRAINT "officines_proprietaire_user_id_users_id_fk" FOREIGN KEY ("proprietaire_user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "partages" ADD CONSTRAINT "partages_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "partages" ADD CONSTRAINT "partages_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "partages" ADD CONSTRAINT "partages_invited_by_users_id_fk" FOREIGN KEY ("invited_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "idx_users_email" ON "users" USING btree ("email");--> statement-breakpoint
CREATE INDEX "idx_users_deleted_at" ON "users" USING btree ("deleted_at") WHERE "users"."deleted_at" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "idx_officines_proprietaire" ON "officines" USING btree ("proprietaire_user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "partages_officine_user_unique" ON "partages" USING btree ("officine_id","user_id") WHERE "partages"."deleted_at" IS NULL;
