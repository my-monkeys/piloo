CREATE TABLE "rappels" (
	"id" uuid PRIMARY KEY NOT NULL,
	"officine_id" uuid NOT NULL,
	"cip13" text NOT NULL,
	"nom_texte" text NOT NULL,
	"unite" text DEFAULT 'comprimé' NOT NULL,
	"quantite_matin" integer,
	"quantite_midi" integer,
	"quantite_soir" integer,
	"quantite_coucher" integer,
	"date_debut" date NOT NULL,
	"date_fin" date,
	"actif" boolean DEFAULT true NOT NULL,
	"notes" text,
	"cree_par_user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "rappels" ADD CONSTRAINT "rappels_officine_id_officines_id_fk" FOREIGN KEY ("officine_id") REFERENCES "public"."officines"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "rappels" ADD CONSTRAINT "rappels_cree_par_user_id_users_id_fk" FOREIGN KEY ("cree_par_user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_rappels_officine_actif" ON "rappels" USING btree ("officine_id","actif");--> statement-breakpoint
CREATE INDEX "idx_rappels_cip13" ON "rappels" USING btree ("cip13");