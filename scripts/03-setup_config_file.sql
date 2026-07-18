-- CHAPTER 2: DATABASE INITIALIZATION & HIGH-VOLUME SEEDING (10M ROW SCALE)
-- Target Database: creditcards
-- =========================================================================

\echo '=== Removing old consumer schema structures if they exist ==='
DROP SCHEMA IF EXISTS consumer CASCADE;

\echo '=== Creating fresh consumer schema ==='
CREATE SCHEMA consumer;

\echo '=== Creating application tables ==='
CREATE TABLE consumer.customers (
    customer_id bigserial PRIMARY KEY,
    first_name varchar(50),
    last_name varchar(50),
    email varchar(100),
    phone_number varchar(20),
    city varchar(50),
    state varchar(50),
    created_date timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE consumer.credit_cards (
    card_id bigserial PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES consumer.customers(customer_id) ON DELETE CASCADE,
    card_number varchar(25) NOT NULL UNIQUE,
    card_type varchar(20),
    credit_limit numeric(12,2),
    issue_date date DEFAULT CURRENT_DATE,
    expiry_date date,
    status varchar(20) DEFAULT 'Active'
);

CREATE TABLE consumer.transactions (
    transaction_id bigserial PRIMARY KEY,
    card_id bigint NOT NULL REFERENCES consumer.credit_cards(card_id) ON DELETE CASCADE,
    merchant_name varchar(100),
    transaction_amount numeric(12,2),
    transaction_date timestamp DEFAULT clock_timestamp(),
    transaction_type varchar(20),
    city varchar(50),
    status varchar(20) DEFAULT 'Approved'
);

CREATE TABLE consumer.payments (
    payment_id bigserial PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES consumer.customers(customer_id) ON DELETE CASCADE,
    payment_amount numeric(12,2),
    payment_method varchar(20),
    payment_date timestamp DEFAULT clock_timestamp()
);

-- =========================================================================
-- HIGH-VOLUME DATA SEEDING (10 MILLION TRANSACTION SCALE)
-- =========================================================================

\echo '=== Seeding 1,000,000 Customers ==='
INSERT INTO consumer.customers (first_name, last_name, email, phone_number, city, state)
SELECT
    'First_' || i,
    'Last_' || i,
    'customer_' || i || '@example.nl',
    '+316' || floor(random() * 90000000 + 10000000)::text,
    CASE floor(random()*4)::int
        WHEN 0 THEN 'Almere'
        WHEN 1 THEN 'Amsterdam'
        WHEN 2 THEN 'Utrecht'
        ELSE 'Rotterdam'
    END,
    'Flevoland'
FROM generate_series(1, 1000000) AS i;

\echo '=== Seeding 1,000,000 Credit Cards (1:1 with Customers) ==='
INSERT INTO consumer.credit_cards (
    customer_id,
    card_number,
    card_type,
    credit_limit,
    issue_date,
    expiry_date,
    status
)
SELECT
    customer_id,
    -- Unique generation using customer_id slices to guarantee zero duplicates
    '4111-' ||
    lpad((customer_id / 100000)::text, 4, '0') ||
    '-' ||
    lpad(((customer_id / 100) % 1000)::text, 3, '0') ||
    '-' ||
    lpad((customer_id % 10000)::text, 4, '0'),
    CASE floor(random() * 3)::int
        WHEN 0 THEN 'Visa'
        WHEN 1 THEN 'Mastercard'
        ELSE 'Amex'
    END,
    (floor(random() * 9 + 1) * 1000)::numeric(12,2),
    CURRENT_DATE - (floor(random() * 1000)::int * interval '1 day'),
    CURRENT_DATE + (floor(random() * 1000)::int * interval '1 day'),
    'Active'
FROM consumer.customers;

\echo '=== Seeding 10,000,000 Transactions (10 per card) ==='
INSERT INTO consumer.transactions (card_id, merchant_name, transaction_amount, transaction_type, city)
SELECT
    card_id,
    'Supermarket_' || floor(random() * 10 + 1)::text,
    (random() * 75 + 5)::numeric(12,2),
    'Purchase',
    'Almere'
FROM consumer.credit_cards, generate_series(1, 10);

\echo '=== Seeding 3,000,000 Payments (3 per customer) ==='
INSERT INTO consumer.payments (customer_id, payment_amount, payment_method)
SELECT
    customer_id,
    (random() * 100 + 10)::numeric(12,2),
    'Direct Debit'
FROM consumer.customers, generate_series(1, 3);

\echo '=== Gathering Statistics (ANALYZE) ==='
ANALYZE consumer.customers;
ANALYZE consumer.credit_cards;
ANALYZE consumer.transactions;
ANALYZE consumer.payments;
