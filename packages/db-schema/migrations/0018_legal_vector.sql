CREATE TABLE "substances_actives_bdpm" (
	"id" uuid PRIMARY KEY NOT NULL,
	"cis" text NOT NULL,
	"code_substance" text NOT NULL,
	"denomination_substance" text NOT NULL,
	"dosage_substance" text,
	"version_bdpm" date NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "substances_actives_bdpm_cis_code_unique" ON "substances_actives_bdpm" USING btree ("cis","code_substance");--> statement-breakpoint
CREATE INDEX "idx_substances_actives_cis" ON "substances_actives_bdpm" USING btree ("cis");