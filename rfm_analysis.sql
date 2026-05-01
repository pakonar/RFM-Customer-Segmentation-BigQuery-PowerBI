/*
===============================================================================
RFM Analysis Project: Customer Segmentation
Tool: Google BigQuery (Standard SQL)
Description: 
    This script performs a full RFM (Recency, Frequency, Monetary) analysis.
    It integrates 12 months of sales data, calculates core metrics, 
    assigns scores using deciles, and segments customers into 8 business categories.
===============================================================================
*/

-- STEP 1: DATA INTEGRATION
-- We combine 12 monthly tables into one consolidated table for the year 2025.
-- We use UNION ALL because all tables share the exact same schema.

CREATE OR REPLACE TABLE `rfm0426.sales.sales_2025` AS
SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202501`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202502`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202503`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202504`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202505`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202506`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202507`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202508`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202509`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202510`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202511`
UNION ALL SELECT OrderID, CustomerID, OrderDate, ProductType, OrderValue FROM `rfm0426.sales.sales202512`;


-- STEP 2: CALCULATE RAW RFM METRICS
-- We use a CTE (Common Table Expression) to define a reference date for analysis.
-- We then aggregate data per CustomerID to find:
-- Recency: Days since the last order.
-- Frequency: Total number of orders.
-- Monetary: Total revenue generated.

CREATE OR REPLACE VIEW `rfm0426.sales.rfm_metrics` AS
WITH current_date AS (
  SELECT DATE('2026-03-06') AS analysis_date -- Reference date for Recency calculation
),
rfm AS (
  SELECT
    CustomerID,
    MAX(OrderDate) AS last_order_date,
    DATE_DIFF((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
    COUNT(*) AS frequency,
    SUM(OrderValue) AS monetary
  FROM `rfm0426.sales.sales_2025` 
  GROUP BY CustomerID
)
-- We use ROW_NUMBER() to create a unique rank for each metric before scoring.
SELECT 
  rfm.*,
  ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank,      -- Lower recency is better
  ROW_NUMBER() OVER(ORDER BY frequency DESC) AS f_rank,   -- Higher frequency is better
  ROW_NUMBER() OVER(ORDER BY monetary DESC) AS m_rank    -- Higher monetary is better
FROM rfm;


-- STEP 3: ASSIGN SCORES (DECILES)
-- We use NTILE(10) to divide customers into 10 equal groups (deciles).
-- We use ORDER BY ... DESC to ensure that the "best" customers (rank 1) 
-- receive the highest score (10).

CREATE OR REPLACE VIEW `rfm0426.sales.rfm_scores` AS 
SELECT 
  *,
  NTILE(10) OVER(ORDER BY r_rank DESC) AS r_score,
  NTILE(10) OVER(ORDER BY f_rank DESC) AS f_score,
  NTILE(10) OVER(ORDER BY m_rank DESC) AS m_score
FROM `rfm0426.sales.rfm_metrics`;


-- STEP 4: CALCULATE TOTAL RFM SCORE
-- We sum the individual R, F, and M scores to get a single value (max 30).
-- This total score will be the basis for our final segmentation.

CREATE OR REPLACE VIEW `rfm0426.sales.rfm_total_scores` AS 
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS rfm_total_score
FROM `rfm0426.sales.rfm_scores`
ORDER BY rfm_total_score DESC;


-- STEP 5: FINAL SEGMENTATION (BI READY TABLE)
-- We use a CASE statement to assign human-readable business segments.
-- This table is optimized for Power BI visualization.

CREATE OR REPLACE TABLE `rfm0426.sales.rfm_segments_table` AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  rfm_total_score,
  CASE
    WHEN rfm_total_score >= 28 THEN 'Champion'             -- Best customers
    WHEN rfm_total_score >= 24 THEN 'Loyal VIPs'           -- High value, loyal
    WHEN rfm_total_score >= 20 THEN 'Potential Loyalists'  -- Active, growing value
    WHEN rfm_total_score >= 16 THEN 'Promising'            -- New and active
    WHEN rfm_total_score >= 12 THEN 'Engaged'              -- Regular customers
    WHEN rfm_total_score >= 8 THEN 'Requires Attention'    -- Starting to cool off
    WHEN rfm_total_score >= 4 THEN 'At Risk'               -- High churn risk
    ELSE 'Lost/Inactive'                                   -- No longer active
  END AS rfm_segment
FROM `rfm0426.sales.rfm_total_scores`
ORDER BY rfm_total_score DESC;

-- End of Script
