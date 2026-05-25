ALTER TABLE "prises_planifiees" ALTER COLUMN "prescription_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "prises_planifiees" ADD COLUMN "rappel_id" uuid;--> statement-breakpoint
ALTER TABLE "prises_planifiees" ADD CONSTRAINT "prises_planifiees_rappel_id_rappels_id_fk" FOREIGN KEY ("rappel_id") REFERENCES "public"."rappels"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
-- Garde-fou : une prise vient d'une prescription OU d'un rappel, pas
-- des deux et pas d'aucun. Drizzle ne génère pas les CHECK depuis le
-- schéma TS, donc on l'ajoute manuellement ici.
ALTER TABLE "prises_planifiees" ADD CONSTRAINT "prises_source_xor" CHECK (
  (prescription_id IS NOT NULL AND rappel_id IS NULL)
  OR (prescription_id IS NULL AND rappel_id IS NOT NULL)
);--> statement-breakpoint
CREATE INDEX "idx_prises_rappel" ON "prises_planifiees" USING btree ("rappel_id");