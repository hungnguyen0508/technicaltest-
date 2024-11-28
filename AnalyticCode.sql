--1. Xử lí dữ lieu: 

-- 1.1. Xử lí giá trị null bang cách thay thế: 

UPDATE orders
SET course_schedule = 'Unknown'
WHERE course_schedule IS NULL;

UPDATE orders
SET payment_status = 'Unknown'
WHERE payment_status IS NULL;

UPDATE orders
SET lead_source = 'Unknown'
WHERE lead_source IS NULL;

UPDATE orders
SET lead_id = 'Unknown'
WHERE lead_id IS NULL;

UPDATE orders
SET course_mode_id = -1
WHERE course_mode_id IS NULL;

UPDATE orders
SET cus_location_id = -1
WHERE cus_location_id IS NULL;

-- 1.2. Bỏ các hang không chứa dữ lieu ở cả 3 cột: 

DELETE FROM your_table_name
WHERE Payment_date IS NULL;

--2. Phân tích tình hình kinh doanh: 

select cast(o.created as date) as Created_date, 
	   o.cus_name as Customer_Name,
	   m.mode as Mode, 
	   l.name as Location, 
	   o.actually_received as Revenue, 
	   o.lead_source as Lead_source
from orders o 
join location l 
	on o.cus_location_id=l.id 
join mode m 
	on o.course_mode_id = m.id 



-- Phân khúc khách hang theo RFM: 
USE test;

WITH full_order AS (
    SELECT 
        CAST(o.created AS DATETIME) AS Created_date, 
        o.cus_name AS Customer_Name,
        m.mode AS Mode, 
        l.name AS Location, 
        o.actually_received AS Revenue, 
        o.lead_source AS Lead_source
    FROM orders o
    JOIN location l ON o.cus_location_id = l.id
    JOIN mode m ON o.course_mode_id = m.id
),
customer_statistics AS (
    SELECT 
        Customer_Name,
        TIMESTAMPDIFF(DAY, MAX(Created_date), CURDATE()) AS recency,
        ROUND(COUNT(DISTINCT Created_date) / TIMESTAMPDIFF(MONTH, MIN(Created_date), CURDATE()), 2) AS frequency,
        SUM(Revenue) AS Monetary_in_currency,
        ROUND(SUM(Revenue) / TIMESTAMPDIFF(MONTH, MIN(Created_date), CURDATE()), 2) AS Monetary,
        ROW_NUMBER() OVER (ORDER BY TIMESTAMPDIFF(DAY, MAX(Created_date), CURDATE())) AS rn_recency,
        ROW_NUMBER() OVER (ORDER BY ROUND(COUNT(DISTINCT Created_date) / TIMESTAMPDIFF(MONTH, MIN(Created_date), CURDATE()), 2)) AS rn_frequency,
        ROW_NUMBER() OVER (ORDER BY ROUND(SUM(Revenue) / TIMESTAMPDIFF(MONTH, MIN(Created_date), CURDATE()), 2)) AS rn_Monetary
    FROM full_order
    GROUP BY Customer_Name
),
RFM AS (
    SELECT 
        Customer_Name, 
        Monetary_in_currency,
        -- Calculate R
        CASE 
            WHEN recency >= (SELECT MIN(recency) FROM customer_statistics)
                 AND recency < (SELECT recency FROM customer_statistics 
                                WHERE rn_recency = (SELECT ROUND(COUNT(Customer_Name) * 0.25, 0) FROM customer_statistics)) THEN 4
            WHEN recency >= (SELECT recency FROM customer_statistics 
                                WHERE rn_recency = (SELECT ROUND(COUNT(Customer_Name) * 0.25, 0) FROM customer_statistics))
                 AND recency < (SELECT recency FROM customer_statistics 
                                WHERE rn_recency = (SELECT ROUND(COUNT(Customer_Name) * 0.5, 0) FROM customer_statistics)) THEN 3
            WHEN recency >= (SELECT recency FROM customer_statistics 
                                WHERE rn_recency = (SELECT ROUND(COUNT(Customer_Name) * 0.5, 0) FROM customer_statistics))
                 AND recency < (SELECT recency FROM customer_statistics 
                                WHERE rn_recency = (SELECT ROUND(COUNT(Customer_Name) * 0.75, 0) FROM customer_statistics)) THEN 2
            ELSE 1 
        END AS R,
        
        -- Calculate F
        CASE 
            WHEN frequency >= (SELECT MIN(frequency) FROM customer_statistics)
                 AND frequency < (SELECT frequency FROM customer_statistics 
                                  WHERE rn_frequency = (SELECT ROUND(COUNT(Customer_Name) * 0.25, 0) FROM customer_statistics)) THEN 1
            WHEN frequency >= (SELECT frequency FROM customer_statistics 
                                  WHERE rn_frequency = (SELECT ROUND(COUNT(Customer_Name) * 0.25, 0) FROM customer_statistics))
                 AND frequency < (SELECT frequency FROM customer_statistics 
                                  WHERE rn_frequency = (SELECT ROUND(COUNT(Customer_Name) * 0.5, 0) FROM customer_statistics)) THEN 2
            WHEN frequency >= (SELECT frequency FROM customer_statistics 
                                  WHERE rn_frequency = (SELECT ROUND(COUNT(Customer_Name) * 0.5, 0) FROM customer_statistics))
                 AND frequency < (SELECT frequency FROM customer_statistics 
                                  WHERE rn_frequency = (SELECT ROUND(COUNT(Customer_Name) * 0.75, 0) FROM customer_statistics)) THEN 3
            ELSE 4 
        END AS F,

        -- Calculate M
        CASE 
            WHEN Monetary >= (SELECT MIN(Monetary) FROM customer_statistics)
                 AND Monetary < (SELECT Monetary FROM customer_statistics 
                                 WHERE rn_Monetary = (SELECT ROUND(COUNT(Customer_Name) * 0.25, 0) FROM customer_statistics)) THEN 1
            WHEN Monetary >= (SELECT Monetary FROM customer_statistics 
                                 WHERE rn_Monetary = (SELECT ROUND(COUNT(Customer_Name) * 0.25, 0) FROM customer_statistics))
                 AND Monetary < (SELECT Monetary FROM customer_statistics 
                                 WHERE rn_Monetary = (SELECT ROUND(COUNT(Customer_Name) * 0.5, 0) FROM customer_statistics)) THEN 2
            WHEN Monetary >= (SELECT Monetary FROM customer_statistics 
                                 WHERE rn_Monetary = (SELECT ROUND(COUNT(Customer_Name) * 0.5, 0) FROM customer_statistics))
                 AND Monetary < (SELECT Monetary FROM customer_statistics 
                                 WHERE rn_Monetary = (SELECT ROUND(COUNT(Customer_Name) * 0.75, 0) FROM customer_statistics)) THEN 3
            ELSE 4 
        END AS M
    FROM customer_statistics
)
select 
    customer_name, 
    monetary_in_currency,
    concat(R,F,M) as Segmentation,
    case 
        when concat(R,F,M) in (444,334,434,344) then 'Khách hàng VIP'
        when concat(R,F,M) in (333,433,343,443) then 'Khách hàng trung thành'
        when concat(R,F,M) in (423,323,313,413) then 'Khách hàng tiềm năng'
        when concat(R,F,M) in (133,143,134,144) then 'Khách hàng sắp rời bỏ'
        else 'Vãng Lai'
    end as Customer_Type
from RFM;
