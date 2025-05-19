USE `adashi_staging`;

## 1. High-Value Customers with Multiple Products
-- Scenario: The business wants to identify customers who have both a savings and an investment plan (cross-selling opportunity).
-- Task: Write a query to find customers with at least one funded savings plan AND one funded investment plan, sorted by total deposits.
/*Tables:
users_customuser
savings_savingsaccount
plans_plan*/

-- Query to find customers who have both funded savings and investment plans
-- sorted by total deposits across both plan types

SELECT 
    u.id AS owner_id,
    u.first_name,
    u.last_name,
    COUNT(DISTINCT CASE WHEN p.is_regular_savings = 1 THEN p.id END) AS savings_count,
    COUNT(DISTINCT CASE WHEN p.is_a_fund = 1 THEN p.id END) AS investment_count,
    ROUND(SUM(s.confirmed_amount) / 100, 2) AS total_deposits
FROM users_customuser u
JOIN plans_plan p ON u.id = p.owner_id
JOIN savings_savingsaccount s ON p.id = s.plan_id AND s.confirmed_amount > 0
WHERE p.is_deleted = 0 AND p.is_archived = 0
GROUP BY u.id, u.first_name, u.last_name
HAVING savings_count > 0 AND investment_count > 0
ORDER BY total_deposits DESC;



## 2. Transaction Frequency Analysis
-- Scenario: The finance team wants to analyze how often customers transact to segment them (e.g., frequent vs. occasional users).
-- Task: Calculate the average number of transactions per customer per month and categorize them:
/* "High Frequency" (≥10 transactions/month)
"Medium Frequency" (3-9 transactions/month)
"Low Frequency" (≤2 transactions/month)
Tables:
users_customuser
savings_savingsaccount*/
 
WITH txn_per_customer_month AS (
    SELECT 
        owner_id,
        COUNT(*) / TIMESTAMPDIFF(MONTH, MIN(transaction_date), MAX(transaction_date)) AS avg_txn_per_month
    FROM savings_savingsaccount
    WHERE transaction_status = 'success'
    GROUP BY owner_id
), frequency_categorized AS (
    SELECT
        CASE 
            WHEN avg_txn_per_month >= 10 THEN 'High Frequency'
            WHEN avg_txn_per_month BETWEEN 3 AND 9 THEN 'Medium Frequency'
            ELSE 'Low Frequency'
        END AS frequency_category,
        avg_txn_per_month
    FROM txn_per_customer_month
)
SELECT 
    frequency_category,
    COUNT(*) AS customer_count,
    ROUND(AVG(avg_txn_per_month), 1) AS avg_transactions_per_month
FROM frequency_categorized
GROUP BY frequency_category;


    

## 3. Account Inactivity Alert
-- Scenario: The ops team wants to flag accounts with no inflow transactions for over one year.
-- Task: Find all active accounts (savings or investments) with no transactions in the last 1 year (365 days) .
/*Tables:
plans_plan
savings_savingsaccount*/

SELECT 
    p.id AS plan_id,
    p.owner_id,
    CASE 
        WHEN p.is_regular_savings = 1 THEN 'Savings'
        WHEN p.is_a_fund = 1 THEN 'Investment'
        ELSE 'Other'
    END AS type,
    MAX(sa.transaction_date) AS last_transaction_date,
    DATEDIFF('2025-05-18', MAX(sa.transaction_date)) AS inactivity_days
FROM plans_plan p
JOIN savings_savingsaccount sa ON sa.plan_id = p.id
GROUP BY p.id, p.owner_id, type
HAVING MAX(sa.transaction_date) < DATE_SUB('2025-05-18', INTERVAL 365 DAY)
LIMIT 0, 365;

## 4.Customer Lifetime Value (CLV) Estimation
-- Scenario: Marketing wants to estimate CLV based on account tenure and transaction volume (simplified model).
-- Task: For each customer, assuming the profit_per_transaction is 0.1% of the transaction value, calculate:
/*Account tenure (months since signup)
Total transactions
Estimated CLV (Assume: CLV = (total_transactions / tenure) * 12 * avg_profit_per_transaction)
Order by estimated CLV from highest to lowest

Tables:
users_customuser
savings_savingsaccount*/
WITH customer_txns AS (
    SELECT 
        u.id AS customer_id,
        u.name,
        TIMESTAMPDIFF(MONTH, u.date_joined, CURDATE()) AS tenure_months,
        COUNT(sa.id) AS total_transactions,
        ROUND(AVG(sa.confirmed_amount * 0.000001), 2) AS avg_profit_per_transaction
    FROM users_customuser u
    JOIN savings_savingsaccount sa ON u.id = sa.owner_id
    JOIN plans_plan p ON sa.plan_id = p.id
    WHERE p.is_regular_savings = 1 OR p.is_a_fund = 1  -- include both savings and investment
    GROUP BY u.id, u.name, u.date_joined
),
clv_calc AS (
    SELECT 
        customer_id,
        name,
        tenure_months,
        total_transactions,
        ROUND((total_transactions / NULLIF(tenure_months, 0)) * 12 * avg_profit_per_transaction, 2) AS estimated_clv
    FROM customer_txns
)
SELECT * FROM clv_calc
ORDER BY estimated_clv DESC;





