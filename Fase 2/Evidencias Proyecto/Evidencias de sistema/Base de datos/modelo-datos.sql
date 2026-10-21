-- Modelo de datos AgeCare (PostgreSQL 16). 

CREATE TABLE content_items (
	content_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	kind VARCHAR(10) NOT NULL, 
	title VARCHAR(200) NOT NULL, 
	body TEXT NOT NULL, 
	source VARCHAR(200), 
	audio_url VARCHAR(1024), 
	locale VARCHAR(10) NOT NULL, 
	published_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	CONSTRAINT pk_content_items PRIMARY KEY (content_id), 
	CONSTRAINT ck_content_items_kind CHECK (kind IN ('joke', 'news'))
);


CREATE TABLE job_offers (
	job_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	description TEXT NOT NULL, 
	zone VARCHAR(100) NOT NULL, 
	schedule VARCHAR(150) NOT NULL, 
	pay_range VARCHAR(100), 
	contact_info VARCHAR(254) NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	published_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_job_offers PRIMARY KEY (job_id)
);


CREATE TABLE marketplace_products (
	product_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	category VARCHAR(20) NOT NULL, 
	description TEXT NOT NULL, 
	price_range VARCHAR(60) NOT NULL, 
	external_url VARCHAR(1024), 
	contact_info VARCHAR(254), 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_marketplace_products PRIMARY KEY (product_id), 
	CONSTRAINT ck_marketplace_products_category CHECK (category IN ('mobility', 'monitoring', 'home_safety', 'daily_care'))
);


CREATE TABLE patients (
	patient_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	full_name VARCHAR(120) NOT NULL, 
	birth_date DATE NOT NULL, 
	sex VARCHAR(10), 
	photo_url VARCHAR(1024), 
	notes TEXT, 
	timezone VARCHAR(64) DEFAULT 'America/Santiago' NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	CONSTRAINT pk_patients PRIMARY KEY (patient_id), 
	CONSTRAINT ck_patients_sex CHECK (sex IN ('female', 'male', 'other'))
);


CREATE TABLE users (
	user_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	email VARCHAR(254) NOT NULL, 
	password_hash VARCHAR(255) NOT NULL, 
	full_name VARCHAR(120) NOT NULL, 
	phone VARCHAR(20), 
	avatar_url VARCHAR(1024), 
	locale VARCHAR(10) DEFAULT 'es' NOT NULL, 
	failed_login_count INTEGER DEFAULT '0' NOT NULL, 
	locked_until TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	CONSTRAINT pk_users PRIMARY KEY (user_id), 
	CONSTRAINT ck_users_locale CHECK (locale IN ('es', 'en')), 
	CONSTRAINT ck_users_failed_login_count CHECK (failed_login_count >= 0), 
	CONSTRAINT uq_users_email UNIQUE (email)
);


CREATE TABLE access_logs (
	access_log_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	patient_id UUID NOT NULL, 
	method VARCHAR(10) NOT NULL, 
	path VARCHAR(500) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_access_logs PRIMARY KEY (access_log_id), 
	CONSTRAINT ck_access_logs_method CHECK (method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE')), 
	CONSTRAINT fk_access_logs_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT fk_access_logs_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE
);

CREATE INDEX ix_access_logs_patient_id ON access_logs (patient_id);

CREATE TABLE alerts (
	alert_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	type VARCHAR(30) NOT NULL, 
	severity VARCHAR(10) NOT NULL, 
	title VARCHAR(200) NOT NULL, 
	detail TEXT NOT NULL, 
	payload JSONB DEFAULT '{}' NOT NULL, 
	status VARCHAR(15) NOT NULL, 
	dedupe_key VARCHAR(200), 
	acknowledged_by UUID, 
	acknowledged_at TIMESTAMP WITH TIME ZONE, 
	resolved_by UUID, 
	resolved_at TIMESTAMP WITH TIME ZONE, 
	resolution_note TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_alerts PRIMARY KEY (alert_id), 
	CONSTRAINT ck_alerts_type CHECK (type IN ('fall', 'vital_out_of_range', 'missed_dose', 'sos', 'wearable_offline')), 
	CONSTRAINT ck_alerts_severity CHECK (severity IN ('info', 'warning', 'critical')), 
	CONSTRAINT ck_alerts_status CHECK (status IN ('active', 'acknowledged', 'resolved')), 
	CONSTRAINT fk_alerts_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT uq_alerts_dedupe_key UNIQUE (dedupe_key), 
	CONSTRAINT fk_alerts_acknowledged_by_users FOREIGN KEY(acknowledged_by) REFERENCES users (user_id) ON DELETE SET NULL, 
	CONSTRAINT fk_alerts_resolved_by_users FOREIGN KEY(resolved_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_alerts_created_at ON alerts (created_at);
CREATE INDEX ix_alerts_patient_status_created ON alerts (patient_id, status, created_at DESC);

CREATE TABLE assistant_conversations (
	conversation_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	title VARCHAR(200) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	last_message_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_assistant_conversations PRIMARY KEY (conversation_id), 
	CONSTRAINT fk_assistant_conversations_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_assistant_conversations_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

CREATE INDEX ix_assistant_conversations_patient_id ON assistant_conversations (patient_id);

CREATE TABLE care_tasks (
	task_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	category VARCHAR(15) NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	start_date DATE NOT NULL, 
	time_of_day TIME WITHOUT TIME ZONE, 
	recurrence VARCHAR(10) NOT NULL, 
	created_by UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	archived_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_care_tasks PRIMARY KEY (task_id), 
	CONSTRAINT ck_care_tasks_category CHECK (category IN ('meal', 'hygiene', 'activity', 'other')), 
	CONSTRAINT ck_care_tasks_recurrence CHECK (recurrence IN ('once', 'daily')), 
	CONSTRAINT fk_care_tasks_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_care_tasks_created_by_users FOREIGN KEY(created_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_care_tasks_patient_id ON care_tasks (patient_id);

CREATE TABLE caregiver_profiles (
	profile_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	headline VARCHAR(150), 
	bio TEXT, 
	years_experience INTEGER, 
	contact_channel VARCHAR(10) NOT NULL, 
	contact_value VARCHAR(254), 
	is_listed BOOLEAN NOT NULL, 
	is_featured BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	CONSTRAINT pk_caregiver_profiles PRIMARY KEY (profile_id), 
	CONSTRAINT ck_caregiver_profiles_contact_channel CHECK (contact_channel IN ('phone', 'whatsapp', 'email')), 
	CONSTRAINT ck_caregiver_profiles_years_experience CHECK (years_experience IS NULL OR years_experience BETWEEN 0 AND 70), 
	CONSTRAINT uq_caregiver_profiles_user_id UNIQUE (user_id), 
	CONSTRAINT fk_caregiver_profiles_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE
);


CREATE TABLE caregiver_subscriptions (
	subscription_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	plan VARCHAR(10) NOT NULL, 
	store VARCHAR(15), 
	purchase_token VARCHAR(1024), 
	valid_until TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_caregiver_subscriptions PRIMARY KEY (subscription_id), 
	CONSTRAINT ck_caregiver_subscriptions_plan CHECK (plan IN ('free', 'premium')), 
	CONSTRAINT ck_caregiver_subscriptions_store CHECK (store IN ('google_play', 'app_store')), 
	CONSTRAINT uq_caregiver_subscriptions_user_id UNIQUE (user_id), 
	CONSTRAINT fk_caregiver_subscriptions_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE
);


CREATE TABLE elder_checkins (
	checkin_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	user_id UUID, 
	feeling VARCHAR(10) NOT NULL, 
	checkin_date DATE NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_elder_checkins PRIMARY KEY (checkin_id), 
	CONSTRAINT uq_elder_checkins_patient_id UNIQUE (patient_id, checkin_date), 
	CONSTRAINT ck_elder_checkins_feeling CHECK (feeling IN ('good', 'regular', 'bad')), 
	CONSTRAINT fk_elder_checkins_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_elder_checkins_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE SET NULL
);


CREATE TABLE handover_notes (
	note_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	author_id UUID, 
	text TEXT NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_handover_notes PRIMARY KEY (note_id), 
	CONSTRAINT fk_handover_notes_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_handover_notes_author_id_users FOREIGN KEY(author_id) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_handover_notes_patient_id ON handover_notes (patient_id);

CREATE TABLE invitations (
	invitation_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	email VARCHAR(254), 
	role VARCHAR(20) NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	code VARCHAR(6) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	created_by UUID NOT NULL, 
	accepted_by UUID, 
	accepted_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_invitations PRIMARY KEY (invitation_id), 
	CONSTRAINT ck_invitations_role CHECK (role IN ('family', 'caregiver', 'doctor', 'elder')), 
	CONSTRAINT ck_invitations_code CHECK (code ~ '^[0-9]{6}$'), 
	CONSTRAINT fk_invitations_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT uq_invitations_token_hash UNIQUE (token_hash), 
	CONSTRAINT fk_invitations_created_by_users FOREIGN KEY(created_by) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT fk_invitations_accepted_by_users FOREIGN KEY(accepted_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_invitations_code ON invitations (code);
CREATE INDEX ix_invitations_patient_id ON invitations (patient_id);

CREATE TABLE medications (
	medication_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	dose VARCHAR(60) NOT NULL, 
	form VARCHAR(40), 
	instructions TEXT, 
	start_date DATE NOT NULL, 
	end_date DATE, 
	grace_window_min INTEGER DEFAULT '60' NOT NULL, 
	prescribed_by UUID, 
	created_by UUID, 
	discontinued_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	CONSTRAINT pk_medications PRIMARY KEY (medication_id), 
	CONSTRAINT ck_medications_grace_window_min CHECK (grace_window_min BETWEEN 5 AND 240), 
	CONSTRAINT ck_medications_date_range CHECK (end_date IS NULL OR end_date >= start_date), 
	CONSTRAINT fk_medications_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_medications_prescribed_by_users FOREIGN KEY(prescribed_by) REFERENCES users (user_id) ON DELETE SET NULL, 
	CONSTRAINT fk_medications_created_by_users FOREIGN KEY(created_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_medications_patient_id ON medications (patient_id);

CREATE TABLE notification_settings (
	notification_setting_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	alert_type VARCHAR(30) NOT NULL, 
	push_enabled BOOLEAN NOT NULL, 
	CONSTRAINT pk_notification_settings PRIMARY KEY (notification_setting_id), 
	CONSTRAINT uq_notification_settings_user_id UNIQUE (user_id, alert_type), 
	CONSTRAINT ck_notification_settings_alert_type CHECK (alert_type IN ('fall', 'vital_out_of_range', 'missed_dose', 'sos', 'wearable_offline')), 
	CONSTRAINT fk_notification_settings_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE
);


CREATE TABLE password_reset_tokens (
	reset_token_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	used_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_password_reset_tokens PRIMARY KEY (reset_token_id), 
	CONSTRAINT fk_password_reset_tokens_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT uq_password_reset_tokens_token_hash UNIQUE (token_hash)
);

CREATE INDEX ix_password_reset_tokens_user_id ON password_reset_tokens (user_id);

CREATE TABLE patient_conditions (
	condition_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	CONSTRAINT pk_patient_conditions PRIMARY KEY (condition_id), 
	CONSTRAINT uq_patient_conditions_patient_id UNIQUE (patient_id, name), 
	CONSTRAINT fk_patient_conditions_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE
);


CREATE TABLE patient_members (
	member_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	role VARCHAR(20) NOT NULL, 
	is_owner BOOLEAN DEFAULT 'false' NOT NULL, 
	joined_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_patient_members PRIMARY KEY (member_id), 
	CONSTRAINT uq_patient_members_patient_id UNIQUE (patient_id, user_id), 
	CONSTRAINT ck_patient_members_role CHECK (role IN ('family', 'caregiver', 'doctor', 'elder')), 
	CONSTRAINT fk_patient_members_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_patient_members_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

CREATE INDEX ix_patient_members_patient_id ON patient_members (patient_id);
CREATE INDEX ix_patient_members_user_id ON patient_members (user_id);

CREATE TABLE product_photos (
	product_id UUID NOT NULL, 
	position SMALLINT NOT NULL, 
	url VARCHAR(1024) NOT NULL, 
	CONSTRAINT pk_product_photos PRIMARY KEY (product_id, position), 
	CONSTRAINT ck_product_photos_position CHECK (position >= 0), 
	CONSTRAINT fk_product_photos_product_id_marketplace_products FOREIGN KEY(product_id) REFERENCES marketplace_products (product_id) ON DELETE CASCADE
);


CREATE TABLE push_devices (
	device_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	push_token VARCHAR(4096) NOT NULL, 
	platform VARCHAR(10) NOT NULL, 
	app_version VARCHAR(30), 
	is_active BOOLEAN DEFAULT 'true' NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	CONSTRAINT pk_push_devices PRIMARY KEY (device_id), 
	CONSTRAINT ck_push_devices_platform CHECK (platform IN ('ios', 'android')), 
	CONSTRAINT fk_push_devices_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT uq_push_devices_push_token UNIQUE (push_token)
);

CREATE INDEX ix_push_devices_user_id ON push_devices (user_id);

CREATE TABLE refresh_tokens (
	refresh_token_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	revoked_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_refresh_tokens PRIMARY KEY (refresh_token_id), 
	CONSTRAINT fk_refresh_tokens_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT uq_refresh_tokens_token_hash UNIQUE (token_hash)
);

CREATE INDEX ix_refresh_tokens_user_id ON refresh_tokens (user_id);

CREATE TABLE uploads (
	upload_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	user_id UUID NOT NULL, 
	purpose VARCHAR(20) NOT NULL, 
	file_name VARCHAR(255) NOT NULL, 
	blob_path VARCHAR(500) NOT NULL, 
	content_type VARCHAR(100) NOT NULL, 
	size_bytes BIGINT NOT NULL, 
	status VARCHAR(10) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_uploads PRIMARY KEY (upload_id), 
	CONSTRAINT ck_uploads_purpose CHECK (purpose IN ('document', 'observation_photo', 'gallery_photo', 'voice_note', 'avatar', 'chat_media')), 
	CONSTRAINT ck_uploads_status CHECK (status IN ('pending', 'uploaded')), 
	CONSTRAINT ck_uploads_size_bytes CHECK (size_bytes > 0), 
	CONSTRAINT fk_uploads_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT uq_uploads_blob_path UNIQUE (blob_path)
);


CREATE TABLE user_preferences (
	user_id UUID NOT NULL, 
	alerts_push BOOLEAN DEFAULT 'true' NOT NULL, 
	alerts_email BOOLEAN DEFAULT 'false' NOT NULL, 
	medication_reminders BOOLEAN DEFAULT 'true' NOT NULL, 
	chat_push BOOLEAN DEFAULT 'true' NOT NULL, 
	digest_daily BOOLEAN DEFAULT 'false' NOT NULL, 
	CONSTRAINT pk_user_preferences PRIMARY KEY (user_id), 
	CONSTRAINT fk_user_preferences_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE
);


CREATE TABLE vital_readings (
	reading_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	type VARCHAR(20) NOT NULL, 
	value FLOAT NOT NULL, 
	value_secondary FLOAT, 
	measured_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	source VARCHAR(10) NOT NULL, 
	meta JSONB, 
	note TEXT, 
	created_by UUID, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	CONSTRAINT pk_vital_readings PRIMARY KEY (reading_id, measured_at), 
	CONSTRAINT uq_vital_readings_patient_id UNIQUE (patient_id, type, measured_at, source), 
	CONSTRAINT ck_vital_readings_type CHECK (type IN ('heart_rate', 'spo2', 'sleep', 'steps', 'sedentary_min', 'fall_event', 'blood_pressure', 'temperature', 'glucose')), 
	CONSTRAINT ck_vital_readings_source CHECK (source IN ('wearable', 'manual')), 
	CONSTRAINT fk_vital_readings_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_vital_readings_created_by_users FOREIGN KEY(created_by) REFERENCES users (user_id) ON DELETE SET NULL
)
 PARTITION BY RANGE (measured_at);

CREATE INDEX ix_vital_readings_patient_type_measured ON vital_readings (patient_id, type, measured_at DESC);

CREATE TABLE vital_thresholds (
	threshold_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	type VARCHAR(20) NOT NULL, 
	min_value FLOAT, 
	max_value FLOAT, 
	updated_by UUID, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_vital_thresholds PRIMARY KEY (threshold_id), 
	CONSTRAINT uq_vital_thresholds_patient_id UNIQUE (patient_id, type), 
	CONSTRAINT ck_vital_thresholds_type CHECK (type IN ('heart_rate', 'spo2', 'sleep', 'steps', 'sedentary_min', 'fall_event', 'blood_pressure', 'temperature', 'glucose')), 
	CONSTRAINT ck_vital_thresholds_not_empty CHECK (min_value IS NOT NULL OR max_value IS NOT NULL), 
	CONSTRAINT ck_vital_thresholds_range CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value), 
	CONSTRAINT fk_vital_thresholds_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_vital_thresholds_updated_by_users FOREIGN KEY(updated_by) REFERENCES users (user_id) ON DELETE SET NULL
);


CREATE TABLE wearables (
	wearable_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	serial_number VARCHAR(100) NOT NULL, 
	model VARCHAR(100) NOT NULL, 
	battery_pct INTEGER, 
	last_sync_at TIMESTAMP WITH TIME ZONE, 
	is_active BOOLEAN DEFAULT 'true' NOT NULL, 
	linked_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_wearables PRIMARY KEY (wearable_id), 
	CONSTRAINT ck_wearables_battery_pct CHECK (battery_pct BETWEEN 0 AND 100), 
	CONSTRAINT fk_wearables_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT uq_wearables_serial_number UNIQUE (serial_number)
);

CREATE INDEX ix_wearables_patient_id ON wearables (patient_id);

CREATE TABLE assistant_messages (
	message_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	conversation_id UUID NOT NULL, 
	sender VARCHAR(10) NOT NULL, 
	text TEXT NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_assistant_messages PRIMARY KEY (message_id), 
	CONSTRAINT ck_assistant_messages_sender CHECK (sender IN ('user', 'assistant')), 
	CONSTRAINT fk_assistant_messages_conversation_id_assistant_conversations FOREIGN KEY(conversation_id) REFERENCES assistant_conversations (conversation_id) ON DELETE CASCADE
);

CREATE INDEX ix_assistant_messages_conversation_id ON assistant_messages (conversation_id);

CREATE TABLE care_task_completions (
	task_id UUID NOT NULL, 
	task_date DATE NOT NULL, 
	status VARCHAR(10) NOT NULL, 
	note TEXT, 
	done_by UUID, 
	done_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_care_task_completions PRIMARY KEY (task_id, task_date), 
	CONSTRAINT ck_care_task_completions_status CHECK (status IN ('pending', 'done', 'skipped')), 
	CONSTRAINT fk_care_task_completions_task_id_care_tasks FOREIGN KEY(task_id) REFERENCES care_tasks (task_id) ON DELETE CASCADE, 
	CONSTRAINT fk_care_task_completions_done_by_users FOREIGN KEY(done_by) REFERENCES users (user_id) ON DELETE SET NULL
);


CREATE TABLE caregiver_languages (
	profile_id UUID NOT NULL, 
	name VARCHAR(40) NOT NULL, 
	CONSTRAINT pk_caregiver_languages PRIMARY KEY (profile_id, name), 
	CONSTRAINT fk_caregiver_languages_profile_id_caregiver_profiles FOREIGN KEY(profile_id) REFERENCES caregiver_profiles (profile_id) ON DELETE CASCADE
);


CREATE TABLE caregiver_reviews (
	review_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	profile_id UUID NOT NULL, 
	author_id UUID NOT NULL, 
	rating INTEGER NOT NULL, 
	comment TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_caregiver_reviews PRIMARY KEY (review_id), 
	CONSTRAINT uq_caregiver_reviews_profile_id UNIQUE (profile_id, author_id), 
	CONSTRAINT ck_caregiver_reviews_rating CHECK (rating BETWEEN 1 AND 5), 
	CONSTRAINT fk_caregiver_reviews_profile_id_caregiver_profiles FOREIGN KEY(profile_id) REFERENCES caregiver_profiles (profile_id) ON DELETE CASCADE, 
	CONSTRAINT fk_caregiver_reviews_author_id_users FOREIGN KEY(author_id) REFERENCES users (user_id) ON DELETE CASCADE
);


CREATE TABLE caregiver_specialties (
	profile_id UUID NOT NULL, 
	name VARCHAR(80) NOT NULL, 
	CONSTRAINT pk_caregiver_specialties PRIMARY KEY (profile_id, name), 
	CONSTRAINT fk_caregiver_specialties_profile_id_caregiver_profiles FOREIGN KEY(profile_id) REFERENCES caregiver_profiles (profile_id) ON DELETE CASCADE
);


CREATE TABLE caregiver_zones (
	profile_id UUID NOT NULL, 
	name VARCHAR(80) NOT NULL, 
	CONSTRAINT pk_caregiver_zones PRIMARY KEY (profile_id, name), 
	CONSTRAINT fk_caregiver_zones_profile_id_caregiver_profiles FOREIGN KEY(profile_id) REFERENCES caregiver_profiles (profile_id) ON DELETE CASCADE
);


CREATE TABLE chat_messages (
	message_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	sender_id UUID, 
	kind VARCHAR(20) NOT NULL, 
	text TEXT, 
	upload_id UUID, 
	duration_sec INTEGER, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_chat_messages PRIMARY KEY (message_id), 
	CONSTRAINT ck_chat_messages_kind CHECK (kind IN ('text', 'voice', 'photo', 'assistant_reply', 'system')), 
	CONSTRAINT ck_chat_messages_duration_sec CHECK (duration_sec IS NULL OR duration_sec >= 0), 
	CONSTRAINT fk_chat_messages_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_chat_messages_sender_id_users FOREIGN KEY(sender_id) REFERENCES users (user_id) ON DELETE SET NULL, 
	CONSTRAINT fk_chat_messages_upload_id_uploads FOREIGN KEY(upload_id) REFERENCES uploads (upload_id) ON DELETE SET NULL
);

CREATE INDEX ix_chat_messages_patient_created ON chat_messages (patient_id, created_at);

CREATE TABLE contact_requests (
	contact_request_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	profile_id UUID NOT NULL, 
	family_user_id UUID NOT NULL, 
	message TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_contact_requests PRIMARY KEY (contact_request_id), 
	CONSTRAINT fk_contact_requests_profile_id_caregiver_profiles FOREIGN KEY(profile_id) REFERENCES caregiver_profiles (profile_id) ON DELETE CASCADE, 
	CONSTRAINT fk_contact_requests_family_user_id_users FOREIGN KEY(family_user_id) REFERENCES users (user_id) ON DELETE CASCADE
);


CREATE TABLE documents (
	document_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	upload_id UUID NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	category VARCHAR(20) NOT NULL, 
	doc_date DATE, 
	uploaded_by UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_documents PRIMARY KEY (document_id), 
	CONSTRAINT ck_documents_category CHECK (category IN ('prescription', 'lab_result', 'medical_report', 'instruction', 'other')), 
	CONSTRAINT fk_documents_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_documents_upload_id_uploads FOREIGN KEY(upload_id) REFERENCES uploads (upload_id) ON DELETE RESTRICT, 
	CONSTRAINT fk_documents_uploaded_by_users FOREIGN KEY(uploaded_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_documents_patient_category ON documents (patient_id, category);

CREATE TABLE incidents (
	incident_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	author_id UUID, 
	type VARCHAR(20) NOT NULL, 
	severity VARCHAR(10) NOT NULL, 
	occurred_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	description TEXT NOT NULL, 
	photo_upload_id UUID, 
	alert_id UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_incidents PRIMARY KEY (incident_id), 
	CONSTRAINT ck_incidents_type CHECK (type IN ('fall', 'pain', 'confusion', 'wandering', 'other')), 
	CONSTRAINT ck_incidents_severity CHECK (severity IN ('low', 'medium', 'critical')), 
	CONSTRAINT fk_incidents_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_incidents_author_id_users FOREIGN KEY(author_id) REFERENCES users (user_id) ON DELETE SET NULL, 
	CONSTRAINT fk_incidents_photo_upload_id_uploads FOREIGN KEY(photo_upload_id) REFERENCES uploads (upload_id) ON DELETE SET NULL, 
	CONSTRAINT fk_incidents_alert_id_alerts FOREIGN KEY(alert_id) REFERENCES alerts (alert_id) ON DELETE SET NULL
);

CREATE INDEX ix_incidents_patient_id ON incidents (patient_id);

CREATE TABLE medication_days (
	medication_id UUID NOT NULL, 
	day_of_week SMALLINT NOT NULL, 
	CONSTRAINT pk_medication_days PRIMARY KEY (medication_id, day_of_week), 
	CONSTRAINT ck_medication_days_day_of_week CHECK (day_of_week BETWEEN 0 AND 6), 
	CONSTRAINT fk_medication_days_medication_id_medications FOREIGN KEY(medication_id) REFERENCES medications (medication_id) ON DELETE CASCADE
);


CREATE TABLE medication_times (
	medication_id UUID NOT NULL, 
	time_of_day TIME WITHOUT TIME ZONE NOT NULL, 
	CONSTRAINT pk_medication_times PRIMARY KEY (medication_id, time_of_day), 
	CONSTRAINT fk_medication_times_medication_id_medications FOREIGN KEY(medication_id) REFERENCES medications (medication_id) ON DELETE CASCADE
);


CREATE TABLE observations (
	observation_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	author_id UUID, 
	category VARCHAR(20) NOT NULL, 
	text TEXT NOT NULL, 
	photo_upload_id UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_observations PRIMARY KEY (observation_id), 
	CONSTRAINT ck_observations_category CHECK (category IN ('mood', 'appetite', 'sleep', 'hygiene', 'activity', 'incident_note', 'general')), 
	CONSTRAINT fk_observations_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_observations_author_id_users FOREIGN KEY(author_id) REFERENCES users (user_id) ON DELETE SET NULL, 
	CONSTRAINT fk_observations_photo_upload_id_uploads FOREIGN KEY(photo_upload_id) REFERENCES uploads (upload_id) ON DELETE SET NULL
);

CREATE INDEX ix_observations_patient_created ON observations (patient_id, created_at DESC);

CREATE TABLE photos (
	photo_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	upload_id UUID NOT NULL, 
	shared_by UUID, 
	caption VARCHAR(300), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_photos PRIMARY KEY (photo_id), 
	CONSTRAINT fk_photos_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_photos_upload_id_uploads FOREIGN KEY(upload_id) REFERENCES uploads (upload_id) ON DELETE RESTRICT, 
	CONSTRAINT fk_photos_shared_by_users FOREIGN KEY(shared_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_photos_patient_id ON photos (patient_id);

CREATE TABLE scheduled_doses (
	dose_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	medication_id UUID NOT NULL, 
	scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	status VARCHAR(12) DEFAULT 'pending' NOT NULL, 
	logged_by UUID, 
	logged_at TIMESTAMP WITH TIME ZONE, 
	reason TEXT, 
	postponed_until TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_scheduled_doses PRIMARY KEY (dose_id), 
	CONSTRAINT uq_scheduled_doses_medication_id UNIQUE (medication_id, scheduled_at), 
	CONSTRAINT ck_scheduled_doses_status CHECK (status IN ('pending', 'taken', 'postponed', 'missed')), 
	CONSTRAINT ck_scheduled_doses_missed_reason CHECK (status <> 'missed' OR reason IS NOT NULL), 
	CONSTRAINT fk_scheduled_doses_medication_id_medications FOREIGN KEY(medication_id) REFERENCES medications (medication_id) ON DELETE CASCADE, 
	CONSTRAINT fk_scheduled_doses_logged_by_users FOREIGN KEY(logged_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX ix_scheduled_doses_scheduled_at ON scheduled_doses (scheduled_at);
CREATE INDEX ix_scheduled_doses_status_scheduled ON scheduled_doses (status, scheduled_at);

CREATE TABLE sos_events (
	sos_event_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	patient_id UUID NOT NULL, 
	triggered_by UUID, 
	note TEXT, 
	lat FLOAT, 
	lng FLOAT, 
	alert_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_sos_events PRIMARY KEY (sos_event_id), 
	CONSTRAINT ck_sos_events_lat CHECK (lat IS NULL OR lat BETWEEN -90 AND 90), 
	CONSTRAINT ck_sos_events_lng CHECK (lng IS NULL OR lng BETWEEN -180 AND 180), 
	CONSTRAINT fk_sos_events_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_sos_events_triggered_by_users FOREIGN KEY(triggered_by) REFERENCES users (user_id) ON DELETE SET NULL, 
	CONSTRAINT uq_sos_events_alert_id UNIQUE (alert_id), 
	CONSTRAINT fk_sos_events_alert_id_alerts FOREIGN KEY(alert_id) REFERENCES alerts (alert_id) ON DELETE CASCADE
);

CREATE INDEX ix_sos_events_patient_id ON sos_events (patient_id);

CREATE TABLE assistant_message_sources (
	source_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	message_id UUID NOT NULL, 
	kind VARCHAR(15) NOT NULL, 
	ref_id VARCHAR(64) NOT NULL, 
	label VARCHAR(200) NOT NULL, 
	CONSTRAINT pk_assistant_message_sources PRIMARY KEY (source_id), 
	CONSTRAINT ck_assistant_message_sources_kind CHECK (kind IN ('vital', 'medication', 'observation', 'alert', 'document')), 
	CONSTRAINT fk_assistant_message_sources_message_id_assistant_messages FOREIGN KEY(message_id) REFERENCES assistant_messages (message_id) ON DELETE CASCADE
);

CREATE INDEX ix_assistant_message_sources_message_id ON assistant_message_sources (message_id);

CREATE TABLE caregiver_certifications (
	certification_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	profile_id UUID NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	issuer VARCHAR(150), 
	year SMALLINT, 
	document_id UUID, 
	CONSTRAINT pk_caregiver_certifications PRIMARY KEY (certification_id), 
	CONSTRAINT ck_caregiver_certifications_year CHECK (year IS NULL OR year BETWEEN 1950 AND 2100), 
	CONSTRAINT fk_caregiver_certifications_profile_id_caregiver_profiles FOREIGN KEY(profile_id) REFERENCES caregiver_profiles (profile_id) ON DELETE CASCADE, 
	CONSTRAINT fk_caregiver_certifications_document_id_documents FOREIGN KEY(document_id) REFERENCES documents (document_id) ON DELETE SET NULL
);

CREATE INDEX ix_caregiver_certifications_profile_id ON caregiver_certifications (profile_id);

CREATE TABLE chat_read_pointers (
	patient_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	last_read_message_id UUID NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_chat_read_pointers PRIMARY KEY (patient_id, user_id), 
	CONSTRAINT fk_chat_read_pointers_patient_id_patients FOREIGN KEY(patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE, 
	CONSTRAINT fk_chat_read_pointers_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT fk_chat_read_pointers_last_read_message_id_chat_messages FOREIGN KEY(last_read_message_id) REFERENCES chat_messages (message_id) ON DELETE CASCADE
);


CREATE TABLE photo_reactions (
	reaction_id UUID DEFAULT gen_random_uuid() NOT NULL, 
	photo_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	kind VARCHAR(10) NOT NULL, 
	upload_id UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	CONSTRAINT pk_photo_reactions PRIMARY KEY (reaction_id), 
	CONSTRAINT ck_photo_reactions_kind CHECK (kind IN ('heart', 'voice')), 
	CONSTRAINT ck_photo_reactions_voice_upload CHECK (kind <> 'voice' OR upload_id IS NOT NULL), 
	CONSTRAINT fk_photo_reactions_photo_id_photos FOREIGN KEY(photo_id) REFERENCES photos (photo_id) ON DELETE CASCADE, 
	CONSTRAINT fk_photo_reactions_user_id_users FOREIGN KEY(user_id) REFERENCES users (user_id) ON DELETE CASCADE, 
	CONSTRAINT fk_photo_reactions_upload_id_uploads FOREIGN KEY(upload_id) REFERENCES uploads (upload_id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX uq_photo_reactions_heart ON photo_reactions (photo_id, user_id) WHERE kind = 'heart';
