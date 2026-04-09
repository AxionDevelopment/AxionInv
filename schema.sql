CREATE TABLE IF NOT EXISTS inventories (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_type VARCHAR(32) NOT NULL,      -- player, vehicle, stash, drop
    owner_id VARCHAR(128) NOT NULL,       -- license/citizenid/plate/custom key
    inventory_type VARCHAR(32) NOT NULL,  -- player, trunk, glovebox, stash, drop
    label VARCHAR(64) DEFAULT NULL,
    slot_count INT NOT NULL DEFAULT 40,
    max_weight INT NOT NULL DEFAULT 30000,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_inventory (owner_type, owner_id, inventory_type)
);

CREATE TABLE IF NOT EXISTS inventory_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    inventory_id BIGINT UNSIGNED NOT NULL,
    slot INT NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT NOT NULL DEFAULT 1,
    metadata JSON DEFAULT NULL,
    durability DECIMAL(10,2) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_slot (inventory_id, slot),
    KEY idx_inventory_id (inventory_id),
    KEY idx_item_name (item_name),
    CONSTRAINT fk_inventory_items_inventory
        FOREIGN KEY (inventory_id) REFERENCES inventories(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS inventory_drops (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    drop_key VARCHAR(64) NOT NULL,
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_drop_key (drop_key)
);

CREATE TABLE IF NOT EXISTS owned_stashes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    stash_key VARCHAR(100) NOT NULL UNIQUE,
    owner_identifier VARCHAR(100) NOT NULL,
    label VARCHAR(100) DEFAULT NULL,
    slots INT NOT NULL DEFAULT 40,
    max_weight INT NOT NULL DEFAULT 50000,
    tier INT NOT NULL DEFAULT 1,
    purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);