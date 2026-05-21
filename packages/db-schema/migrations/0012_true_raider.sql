CREATE TABLE "bdpm_notices_cache" (
	"cis" text PRIMARY KEY NOT NULL,
	"source_url" text NOT NULL,
	"sections" jsonb NOT NULL,
	"scraped_at" timestamp with time zone DEFAULT now() NOT NULL,
	"refreshing" boolean DEFAULT false NOT NULL
);
