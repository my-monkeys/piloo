CREATE TABLE "invitations" (
	"id" uuid PRIMARY KEY NOT NULL,
	"officine_id" uuid NOT NULL,
	"role" "role_partage" NOT NULL,
	"invited_by_user_id" uuid NOT NULL,
	"email" text,
	"expires_at" timestamp with time zone NOT NULL,
	"accepted_at" timestamp with time zone,
	"accepted_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_invited_by_user_id_users_id_fk" FOREIGN KEY ("invited_by_user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_accepted_by_user_id_users_id_fk" FOREIGN KEY ("accepted_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_invitations_officine" ON "invitations" USING btree ("officine_id");--> statement-breakpoint
CREATE INDEX "idx_invitations_expires" ON "invitations" USING btree ("expires_at");