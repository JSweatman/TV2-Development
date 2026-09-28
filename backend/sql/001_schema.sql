-- TV2 resolver schema v0.3
-- Public resolver data only. CDD, consent records, credentials, and private
-- communications routes MUST live behind separate service/database boundaries.

CREATE TABLE IF NOT EXISTS listings (
    id BIGSERIAL PRIMARY KEY,
    country_code TEXT NULL,
    list_number VARCHAR(15) NOT NULL,
    tldx TEXT NULL,
    display_name VARCHAR(200) NOT NULL,
    entity_type VARCHAR(40) NOT NULL,
    template_key VARCHAR(80) NOT NULL DEFAULT 'basic',
    resolution_state VARCHAR(20) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_list_number_length CHECK (char_length(list_number) BETWEEN 1 AND 15),
    CONSTRAINT chk_resolution_state CHECK (resolution_state IN ('draft','active','suspended','retired'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_listing_namespace
    ON listings (COALESCE(country_code,'__GLOBAL__'), list_number, COALESCE(tldx,'__NONE__'));
CREATE INDEX IF NOT EXISTS ix_listing_resolution
    ON listings (country_code, list_number)
    WHERE resolution_state='active';

CREATE TABLE IF NOT EXISTS listing_resources (
    id BIGSERIAL PRIMARY KEY,
    listing_id BIGINT NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    resource_key VARCHAR(60) NOT NULL,
    resource_type VARCHAR(40) NOT NULL,
    public_uri TEXT NULL,
    public_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_listing_resource_key UNIQUE(listing_id, resource_key)
);

CREATE INDEX IF NOT EXISTS ix_listing_resources_enabled
    ON listing_resources (listing_id, resource_key)
    WHERE enabled=TRUE;

CREATE TABLE IF NOT EXISTS listing_buttons (
    id BIGSERIAL PRIMARY KEY,
    listing_id BIGINT NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    slot SMALLINT NOT NULL,
    label VARCHAR(40) NULL,
    resource_id BIGINT NOT NULL REFERENCES listing_resources(id) ON DELETE CASCADE,
    CONSTRAINT chk_button_slot CHECK (slot BETWEEN 1 AND 9),
    CONSTRAINT uq_listing_button_slot UNIQUE(listing_id, slot)
);
