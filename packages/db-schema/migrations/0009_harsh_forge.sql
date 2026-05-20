-- Refonte `medicaments_bdpm` : PK = cip13 (au lieu de cis).
--
-- POURQUOI : un médicament (CIS) a N présentations (CIP13). En stockant
-- une seule ligne par CIS on perd les CIPs des autres tailles de boîte,
-- d'où des miss systématiques lors des scans (ex. CIP 3400921905076
-- absent alors qu'on a 3400921904826 pour le même médicament).
-- Cf. apps/web/lib/bdpm/parser.ts §combine() + ticket #48.
--
-- DONNÉES : `medicaments_bdpm` est un cache de la base BDPM publique
-- (data.gouv.fr), reconstruit à chaque import (cron mensuel #74). On
-- peut donc DROP + CREATE sans perte — le prochain import repeuplera
-- la table avec ~37k lignes au lieu de ~14k.

DROP TABLE IF EXISTS "medicaments_bdpm";
--> statement-breakpoint
CREATE TABLE "medicaments_bdpm" (
    "cip13" text PRIMARY KEY NOT NULL,
    "cip7" text,
    "cis" text NOT NULL,
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
CREATE INDEX "idx_bdpm_cis" ON "medicaments_bdpm" USING btree ("cis");
--> statement-breakpoint
CREATE INDEX "idx_bdpm_denomination" ON "medicaments_bdpm" USING btree ("denomination");
