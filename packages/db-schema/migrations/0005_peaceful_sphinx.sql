CREATE TYPE "public"."sync_op_status" AS ENUM('applied', 'conflict', 'rejected');--> statement-breakpoint
CREATE TABLE "sync_operations_log" (
	"id" uuid PRIMARY KEY NOT NULL,
	"operation_id" text NOT NULL,
	"client_id" text NOT NULL,
	"user_id" uuid NOT NULL,
	"type" text NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" uuid NOT NULL,
	"payload" jsonb NOT NULL,
	"timestamp_local" bigint NOT NULL,
	"status" "sync_op_status" NOT NULL,
	"reason" text,
	"server_version" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "sync_operations_log" ADD CONSTRAINT "sync_operations_log_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "idx_sync_op_unique_operation_id" ON "sync_operations_log" USING btree ("operation_id");--> statement-breakpoint
CREATE INDEX "idx_sync_op_user_created" ON "sync_operations_log" USING btree ("user_id","created_at");