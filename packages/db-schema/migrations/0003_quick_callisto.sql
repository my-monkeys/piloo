CREATE TYPE "public"."type_alerte" AS ENUM('peremption_30j', 'peremption_7j', 'stock_bas', 'prise_oubliee', 'manque_signale');--> statement-breakpoint
CREATE TABLE "alertes" (
	"id" uuid PRIMARY KEY NOT NULL,
	"officine_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"type" "type_alerte" NOT NULL,
	"payload" jsonb NOT NULL,
	"lue_a" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "alertes" ADD CONSTRAINT "alertes_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "alertes" ADD CONSTRAINT "alertes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_alertes_user_non_lues" ON "alertes" USING btree ("user_id","created_at") WHERE "alertes"."lue_a" IS NULL AND "alertes"."deleted_at" IS NULL;--> statement-breakpoint
CREATE INDEX "idx_alertes_user_lue_a" ON "alertes" USING btree ("user_id","lue_a");