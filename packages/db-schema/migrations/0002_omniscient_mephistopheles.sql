CREATE TYPE "public"."source_ordonnance" AS ENUM('manuelle', 'ocr');--> statement-breakpoint
CREATE TYPE "public"."statut_prise" AS ENUM('prevue', 'prise', 'sautee', 'oubliee');--> statement-breakpoint
CREATE TABLE "ordonnances" (
	"id" uuid PRIMARY KEY NOT NULL,
	"officine_id" uuid NOT NULL,
	"prescripteur" text,
	"date_prescription" date NOT NULL,
	"source" "source_ordonnance" DEFAULT 'manuelle' NOT NULL,
	"photo_url" text,
	"notes" text,
	"saisie_par" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "prescriptions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"ordonnance_id" uuid NOT NULL,
	"cip13" text,
	"cis" text,
	"nom_texte" text NOT NULL,
	"posologie" jsonb NOT NULL,
	"duree_jours" integer,
	"indication" text,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "prises_planifiees" (
	"id" uuid PRIMARY KEY NOT NULL,
	"prescription_id" uuid NOT NULL,
	"officine_id" uuid NOT NULL,
	"datetime_prevue" timestamp with time zone NOT NULL,
	"datetime_validation" timestamp with time zone,
	"statut" "statut_prise" DEFAULT 'prevue' NOT NULL,
	"validee_par" uuid,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "ordonnances" ADD CONSTRAINT "ordonnances_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ordonnances" ADD CONSTRAINT "ordonnances_saisie_par_users_id_fk" FOREIGN KEY ("saisie_par") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_ordonnance_id_ordonnances_id_fk" FOREIGN KEY ("ordonnance_id") REFERENCES "public"."ordonnances"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prises_planifiees" ADD CONSTRAINT "prises_planifiees_prescription_id_prescriptions_id_fk" FOREIGN KEY ("prescription_id") REFERENCES "public"."prescriptions"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prises_planifiees" ADD CONSTRAINT "prises_planifiees_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prises_planifiees" ADD CONSTRAINT "prises_planifiees_validee_par_users_id_fk" FOREIGN KEY ("validee_par") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_ordonnances_officine" ON "ordonnances" USING btree ("officine_id");--> statement-breakpoint
CREATE INDEX "idx_prescriptions_ordonnance" ON "prescriptions" USING btree ("ordonnance_id");--> statement-breakpoint
CREATE INDEX "idx_prescriptions_cip13" ON "prescriptions" USING btree ("cip13");--> statement-breakpoint
CREATE INDEX "idx_prises_officine_datetime" ON "prises_planifiees" USING btree ("officine_id","datetime_prevue");--> statement-breakpoint
CREATE INDEX "idx_prises_statut_datetime" ON "prises_planifiees" USING btree ("statut","datetime_prevue");