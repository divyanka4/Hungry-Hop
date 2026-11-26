-- R5 — Governance: admin roster, contact masking (SOP-08), proofs, and grants.
-- Mask rule (SOP-08 Customer Data and Privacy): outside the support admin group,
-- email and phone are shown masked as four stars followed by the last 4 characters.

-- 1) Support admin roster. Users listed here see unmasked contact details.
CREATE OR REPLACE TABLE hop.gov.admin_users (
  user_name STRING NOT NULL COMMENT 'support admin who may see unmasked contact details'
) COMMENT 'R5: support admin group roster';

INSERT INTO hop.gov.admin_users VALUES (current_user());

-- 2) Mask function used by the column masks.
CREATE OR REPLACE FUNCTION hop.gov.mask_contact(v STRING)
RETURNS STRING
COMMENT 'R5: masks email/phone for non-admins as four stars + last 4 characters (SOP-08)'
RETURN CASE
  WHEN EXISTS (SELECT 1 FROM hop.gov.admin_users WHERE user_name = current_user()) THEN v
  ELSE concat('****', right(v, 4))
END;

-- 3) Attach the mask to customer contact columns.
ALTER TABLE hop.raw.customers ALTER COLUMN email SET MASK hop.gov.mask_contact;
ALTER TABLE hop.raw.customers ALTER COLUMN phone SET MASK hop.gov.mask_contact;

-- 4) Proof table: expected masked rendering of customer contacts.
CREATE OR REPLACE TABLE hop.gov.r5_mask_proof AS
SELECT
  c.customer_id,
  c.email AS email_admin_view,
  concat('****', right(c.email, 4)) AS email_masked,
  c.phone AS phone_admin_view,
  concat('****', right(c.phone, 4)) AS phone_masked
FROM hop.raw.customers c
ORDER BY c.customer_id
LIMIT 5;

COMMENT ON TABLE hop.gov.r5_mask_proof IS
  'R5 proof: expected masked rendering (four stars + last 4 chars) of customer email/phone for non-admins (SOP-08)';

-- 5) Grants: account users get read access to the curated zones.
--    SELECT on admin_users keeps the mask subquery from failing closed for non-admins.
GRANT USE CATALOG ON CATALOG hop TO `account users`;
GRANT USE SCHEMA ON SCHEMA hop.gold TO `account users`;
GRANT SELECT ON SCHEMA hop.gold TO `account users`;
GRANT USE SCHEMA ON SCHEMA hop.analytics TO `account users`;
GRANT SELECT ON SCHEMA hop.analytics TO `account users`;
GRANT USE SCHEMA ON SCHEMA hop.gov TO `account users`;
GRANT SELECT ON TABLE hop.gov.admin_users TO `account users`;
