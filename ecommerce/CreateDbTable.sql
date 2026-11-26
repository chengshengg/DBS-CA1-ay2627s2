-- ============================================
-- CREATE DATABASE (run separately in psql)
-- ============================================
-- CREATE DATABASE ecommerce;

-- ============================================
-- DROP EXISTING TABLES (for clean setup)
-- ============================================

DROP TABLE IF EXISTS public.comment CASCADE;
DROP TABLE IF EXISTS public.review CASCADE;
DROP TABLE IF EXISTS public.sale_order_item CASCADE;
DROP TABLE IF EXISTS public.sale_order CASCADE;
DROP TABLE IF EXISTS public.member CASCADE;
DROP TABLE IF EXISTS public.member_role CASCADE;
DROP TABLE IF EXISTS public.product CASCADE;

-- ============================================
-- CREATE TABLES (Pre-existing schema)
-- ============================================

CREATE TABLE public.member_role (
    id SERIAL PRIMARY KEY,
    name CHARACTER VARYING(25)
);

CREATE TABLE public.member (
    id SERIAL PRIMARY KEY,
    username CHARACTER VARYING(50) NOT NULL UNIQUE,
    email CHARACTER VARYING(50) NOT NULL UNIQUE,
    dob DATE NOT NULL,
    password CHARACTER VARYING(255) NOT NULL,
    role INTEGER NOT NULL,
    gender CHARACTER(1) NOT NULL,
    CONSTRAINT fk_member_role_id FOREIGN KEY (role) REFERENCES public.member_role(id)
);

CREATE TABLE public.product (
    id SERIAL PRIMARY KEY,
    name CHARACTER VARYING(255),
    description TEXT,
    unit_price NUMERIC NOT NULL,
    stock_quantity NUMERIC DEFAULT 0 NOT NULL,
    country CHARACTER VARYING(100),
    product_type CHARACTER VARYING(50),
    image_url CHARACTER VARYING(255) DEFAULT '/images/product.png',
    manufactured_on TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE public.sale_order (
    id SERIAL PRIMARY KEY,
    member_id INTEGER,
    order_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    status CHARACTER VARYING(10),
    CONSTRAINT fk_sale_order_member FOREIGN KEY (member_id) REFERENCES public.member(id)
);

CREATE TABLE public.sale_order_item (
    id SERIAL PRIMARY KEY,
    sale_order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity NUMERIC NOT NULL,
    CONSTRAINT fk_sale_order_item_sale_order FOREIGN KEY (sale_order_id) REFERENCES public.sale_order(id),
    CONSTRAINT fk_sale_order_item_product FOREIGN KEY (product_id) REFERENCES public.product(id)
);


-- ============================================
-- CA1: REVIEW & COMMENT TABLES
-- ============================================

-- --------------------------------------------
-- review: one review per member per product.
-- Eligibility (member must have a COMPLETED order containing the product)
-- spans several tables, so it is enforced in create_review, not here.
-- --------------------------------------------
CREATE TABLE public.review (
    id          SERIAL PRIMARY KEY,
    member_id   INTEGER  NOT NULL,
    product_id  INTEGER  NOT NULL,
    rating      SMALLINT NOT NULL,
    review_text TEXT     NOT NULL,
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_review_member  FOREIGN KEY (member_id)  REFERENCES public.member(id)  ON DELETE CASCADE,
    CONSTRAINT fk_review_product FOREIGN KEY (product_id) REFERENCES public.product(id) ON DELETE CASCADE,
    CONSTRAINT uq_review_member_product UNIQUE (member_id, product_id),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_review_text   CHECK (LENGTH(TRIM(review_text)) BETWEEN 1 AND 1000),
    CONSTRAINT chk_review_dates  CHECK (updated_at >= created_at)
);

-- uq_review_member_product already indexes (member_id, ...) for get_reviews;
-- this index serves "all reviews for a product" on the product page.
CREATE INDEX idx_review_product_id ON public.review(product_id);

-- --------------------------------------------
-- comment: self-referencing (adjacency list) to support nested replies.
--   parent_comment_id IS NULL  -> top-level comment on the review
--   parent_comment_id NOT NULL -> reply to another comment
-- --------------------------------------------
CREATE TABLE public.comment (
    id                SERIAL PRIMARY KEY,
    review_id         INTEGER NOT NULL,
    member_id         INTEGER NOT NULL,
    parent_comment_id INTEGER,
    comment_text      TEXT    NOT NULL,
    created_at        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at        TIMESTAMP WITHOUT TIME ZONE,          -- soft delete marker
    -- Target of the composite FK below: lets a reply prove its parent is on the same review
    CONSTRAINT uq_comment_id_review UNIQUE (id, review_id),
    CONSTRAINT fk_comment_review FOREIGN KEY (review_id) REFERENCES public.review(id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_member FOREIGN KEY (member_id) REFERENCES public.member(id) ON DELETE CASCADE,
    -- A reply must belong to the same review as its parent comment
    CONSTRAINT fk_comment_parent FOREIGN KEY (parent_comment_id, review_id)
        REFERENCES public.comment(id, review_id) ON DELETE CASCADE,
    CONSTRAINT chk_comment_not_self_parent CHECK (parent_comment_id IS NULL OR parent_comment_id <> id),
    CONSTRAINT chk_comment_text CHECK (LENGTH(TRIM(comment_text)) BETWEEN 1 AND 500),
    CONSTRAINT chk_comment_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE INDEX idx_comment_review_id ON public.comment(review_id);
CREATE INDEX idx_comment_parent_id ON public.comment(parent_comment_id);
CREATE INDEX idx_comment_member_id ON public.comment(member_id);
