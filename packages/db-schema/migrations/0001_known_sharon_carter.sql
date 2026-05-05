CREATE TYPE "public"."statut_boite" AS ENUM('active', 'vide', 'perimee');--> statement-breakpoint
CREATE TABLE "medicaments_bdpm" (
	"cis" text PRIMARY KEY NOT NULL,
	"cip13" text,
	"cip7" text,
	"denomination" text NOT NULL,
	"forme" text,
	"dosage" text,
	"voie_administration" text,
	"titulaire" text,
	"statut_amm" text,
	"taux_remboursement" integer,
	"version_bdpm" date NOT NULL
);
--> statement-breakpoint
CREATE TABLE "boites" (
	"id" uuid PRIMARY KEY NOT NULL,
	"officine_id" uuid NOT NULL,
	"cip13" text NOT NULL,
	"lot" text,
	"numero_serie" text,
	"peremption" date NOT NULL,
	"unites_initiales" integer,
	"unites_restantes" integer,
	"statut" "statut_boite" DEFAULT 'active' NOT NULL,
	"notes" text,
	"ajoutee_par" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "boites" ADD CONSTRAINT "boites_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "boites" ADD CONSTRAINT "boites_ajoutee_par_users_id_fk" FOREIGN KEY ("ajoutee_par") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_bdpm_cip13" ON "medicaments_bdpm" USING btree ("cip13");--> statement-breakpoint
CREATE INDEX "idx_bdpm_denomination" ON "medicaments_bdpm" USING btree ("denomination");--> statement-breakpoint
CREATE UNIQUE INDEX "boites_officine_cip13_lot_serie_unique" ON "boites" USING btree ("officine_id","cip13","lot","numero_serie") WHERE "boites"."deleted_at" IS NULL AND "boites"."numero_serie" IS NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "boites_officine_cip13_lot_unique" ON "boites" USING btree ("officine_id","cip13","lot") WHERE "boites"."deleted_at" IS NULL AND "boites"."numero_serie" IS NULL AND "boites"."lot" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "idx_boites_officine_statut" ON "boites" USING btree ("officine_id","statut");--> statement-breakpoint
CREATE INDEX "idx_boites_cip13" ON "boites" USING btree ("cip13");--> statement-breakpoint
CREATE INDEX "idx_boites_peremption" ON "boites" USING btree ("peremption");