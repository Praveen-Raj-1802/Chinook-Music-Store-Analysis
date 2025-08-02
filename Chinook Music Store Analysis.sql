use chinook;

-- **********************************Objective Questions*******************************

-- 1. Does any table have missing values or duplicates? If yes how would you handle it ?

-- Filled missing company with 'N/A'
UPDATE customer
SET company = 'N/A'
WHERE company IS NULL;

-- Filled missing state with 'Unknown'
UPDATE customer
SET state = 'Unknown'
WHERE state IS NULL;

-- Filled missing postal_code with '00000'
UPDATE customer
SET postal_code = '00000'
WHERE postal_code IS NULL;

-- Filled missing fax with 'N/A'
UPDATE customer
SET fax = 'N/A'
WHERE fax IS NULL;

-- Filled missing phone with 'Missing'
UPDATE customer
SET phone = 'Missing'
WHERE phone IS NULL;

-- General Manager so no action needed for the missing value in reports to column
SELECT *
FROM employee
WHERE reports_to IS NULL;

UPDATE track
SET composer = 'Unknown'
WHERE composer IS NULL;

-- 2.Find the top-selling tracks and top artist in the USA and identify their most famous genres.

SELECT
    t.name AS track_name,
    g.name AS genre_name,
    SUM(il.unit_price * il.quantity) AS total_sales,
    SUM(il.quantity) AS total_quantity
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE c.country = 'USA'
GROUP BY t.track_id, t.name, g.name
ORDER BY total_sales DESC
LIMIT 5;

SELECT
    ar.name AS artist_name,
    SUM(il.unit_price * il.quantity) AS total_sales
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE c.country = 'USA'
GROUP BY ar.artist_id, ar.name
ORDER BY total_sales DESC
LIMIT 1;

-- 3. What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

SELECT country, COUNT(*) AS num_customers
FROM customer
GROUP BY country
ORDER BY num_customers DESC;

-- 4. Calculate the total revenue and number of invoices for each country, state, and city:

-- Total Revenue and invoices by Country
SELECT
  billing_country AS country,
  COUNT(*) AS num_invoices,
  SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country
ORDER BY total_revenue DESC;

-- Total Revenue and invoices by Country and State

SELECT
  billing_country AS country,
  billing_state AS state,
  COUNT(*) AS num_invoices,
  SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country, billing_state
ORDER BY total_revenue DESC;

-- Total Revenue and invoices by Country, State and City

SELECT
  billing_country AS country,
  billing_state AS state,
  billing_city AS city,
  COUNT(*) AS num_invoices,
  SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country, billing_state, billing_city
ORDER BY total_revenue DESC;

-- 5. Find the top 5 customers by total revenue in each country

with customer_revenue AS (
  SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country,
    SUM(i.total) AS total_revenue
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name, c.country
),
ranked_customers AS (
  SELECT *,
         rank() OVER (PARTITION BY country ORDER BY total_revenue DESC) AS rnk
  FROM customer_revenue
)
SELECT *
FROM ranked_customers
WHERE rnk <= 5
ORDER BY country, total_revenue DESC;

-- 6. Identify the top-selling track for each customer

WITH customer_track_revenue AS (
  SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    t.name AS track_name,
    t.track_id,
    SUM(il.unit_price * il.quantity) AS total_spent,
    SUM(il.quantity) AS total_quantity
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  GROUP BY c.customer_id, t.track_id, t.name, c.first_name, c.last_name
),
ranked_tracks AS (
  SELECT *, rank() OVER (PARTITION BY customer_id ORDER BY total_spent DESC) AS rnk
  FROM customer_track_revenue
)
SELECT
  customer_id,
  first_name,
  last_name,
  track_name,
  total_spent,
  total_quantity
FROM ranked_tracks
WHERE rnk = 1
ORDER BY total_spent DESC;

-- 7. Are there any patterns or trends in customer purchasing behavior(e.g., frequency of purchases, preferred payment methods,average order value)?

-- Purchase Frequency (Invoices per Customer)

SELECT
  c.customer_id,
  c.first_name,
  c.last_name,
  COUNT(i.invoice_id) AS num_purchases
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY num_purchases DESC;

--  Average Order Value per Customer

SELECT
  c.customer_id,
  c.first_name,
  c.last_name,
  COUNT(i.invoice_id) AS num_orders,
  SUM(i.total) AS total_spent,
  AVG(i.total) AS avg_order_value
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC;

-- Monthly Trends

SELECT
  DATE_FORMAT(invoice_date, '%M') AS month,
  COUNT(*) AS total_orders,
  SUM(total) AS total_revenue
FROM invoice
GROUP BY DATE_FORMAT(invoice_date, '%M')
ORDER BY DATE_FORMAT(invoice_date, '%m');

-- 8. What is the customer churn rate?

WITH customer_last_purchase AS (
  SELECT
    c.customer_id,
    MAX(i.invoice_date) AS last_purchase
  FROM customer c
  LEFT JOIN invoice i ON c.customer_id = i.customer_id
  GROUP BY c.customer_id
),
latest_date AS (
  SELECT MAX(invoice_date) AS max_invoice_date FROM invoice
)

SELECT
  COUNT(*) AS total_customers,
  SUM(CASE
        WHEN clp.last_purchase < DATE_SUB(ld.max_invoice_date, INTERVAL 3 MONTH)
          OR clp.last_purchase IS NULL
        THEN 1 ELSE 0
      END) AS churned_customers,
  ROUND(
    SUM(CASE
          WHEN clp.last_purchase < DATE_SUB(ld.max_invoice_date, INTERVAL 3 MONTH)
            OR clp.last_purchase IS NULL
          THEN 1 ELSE 0
        END) / COUNT(*) * 100, 2
  ) AS churn_rate_percent
FROM customer_last_purchase clp
CROSS JOIN latest_date ld;

-- 9. Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

CREATE VIEW usa_track_sales AS
SELECT
  il.invoice_line_id,
  il.unit_price * il.quantity AS revenue,
  il.track_id,
  t.name AS track_name,
  g.name AS genre_name,
  a.name AS artist_name
FROM invoice i
JOIN customer c ON i.customer_id = c.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN album al ON t.album_id = al.album_id
JOIN artist a ON al.artist_id = a.artist_id
WHERE c.country = 'USA';

SELECT genre_name,
ROUND(SUM(revenue) / (SELECT SUM(revenue) FROM usa_track_sales) * 100, 2) AS genre_percentage
FROM usa_track_sales
GROUP BY genre_name
ORDER BY genre_percentage DESC;

SELECT artist_name,
SUM(revenue) AS artist_revenue
FROM usa_track_sales
GROUP BY artist_name
ORDER BY artist_revenue DESC;


-- 10. Find customers who have purchased tracks from at least 3 different genres

SELECT
  c.customer_id,
  c.first_name,
  c.last_name,
  COUNT(DISTINCT g.genre_id) AS genre_count
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING genre_count >= 3
ORDER BY genre_count DESC;

-- 11. Rank genres based on their sales performance in the USA

with genre_sum_revenue as(SELECT
  genre_name,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM usa_track_sales
GROUP BY genre_name
ORDER BY total_revenue DESC)
 
select genre_name, total_revenue,
RANK() OVER (ORDER BY total_revenue DESC) AS genre_rank
FROM genre_sum_revenue
GROUP BY genre_name
ORDER BY total_revenue DESC;

-- 12. Identify customers who have not made a purchase in the last 3 months

with customer_last_purchase AS (
  SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    MAX(i.invoice_date) AS last_purchase
  FROM customer c
  LEFT JOIN invoice i ON c.customer_id = i.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name
),
latest_date AS (
  SELECT MAX(invoice_date) AS max_invoice_date FROM invoice
)

SELECT
  clp.customer_id,
  clp.first_name,
  clp.last_name
FROM customer_last_purchase clp
CROSS JOIN latest_date ld
WHERE clp.last_purchase < DATE_SUB(ld.max_invoice_date, INTERVAL 3 MONTH)
   OR clp.last_purchase IS NULL
ORDER BY clp.last_purchase;



-- **********************************Subjective Questions*******************************

-- 1. Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

WITH usa_genre_sales AS (
  SELECT g.name AS genre_name, SUM(il.unit_price * il.quantity) AS revenue
  FROM invoice i
  JOIN customer c ON i.customer_id = c.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN genre g ON t.genre_id = g.genre_id
  WHERE c.country = 'USA'
  GROUP BY g.name
),

top_genres AS (
  SELECT genre_name
  FROM usa_genre_sales
  ORDER BY revenue DESC
  LIMIT 3
),

top_albums AS (
  SELECT g.name AS genre_name, al.title AS album_title, ar.name AS artist_name,
    SUM(il.unit_price * il.quantity) AS revenue
  FROM invoice i
  JOIN customer c ON i.customer_id = c.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN album al ON t.album_id = al.album_id
  JOIN artist ar ON al.artist_id = ar.artist_id
  JOIN genre g ON t.genre_id = g.genre_id
  WHERE c.country = 'USA'
    AND g.name IN (SELECT genre_name FROM top_genres)
  GROUP BY g.name, al.title, ar.name
)

SELECT *
FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY genre_name ORDER BY revenue DESC) AS rn 
  FROM top_albums
) ranked
WHERE rn = 1;


-- 2. Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

WITH international_sales AS (
  SELECT
    g.name AS genre_name,
    c.country,
    il.unit_price * il.quantity AS revenue
  FROM invoice i
  JOIN customer c ON i.customer_id = c.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN genre g ON t.genre_id = g.genre_id
  WHERE c.country <> 'USA'
),
genre_country_sales AS (
  SELECT
    country,
    genre_name,
    ROUND(SUM(revenue), 2) AS total_revenue
  FROM international_sales
  GROUP BY country, genre_name
),
ranked_genres AS (
  SELECT *,
         RANK() OVER (PARTITION BY country ORDER BY total_revenue DESC) AS genre_rank
  FROM genre_country_sales
)
SELECT *
FROM ranked_genres
WHERE genre_rank = 1
ORDER BY country;

-- 3. Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?

WITH customer_first_last AS (
  SELECT
    c.customer_id,
    MIN(i.invoice_date) AS first_purchase, MAX(i.invoice_date) AS last_purchase,
    COUNT(i.invoice_id) AS total_orders, SUM(il.unit_price * il.quantity) AS total_spent,
    ROUND(SUM(il.unit_price * il.quantity) / COUNT(i.invoice_id), 2) AS avg_order_value,
    ROUND(SUM(il.quantity) / COUNT(i.invoice_id), 2) AS avg_basket_size
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  GROUP BY c.customer_id
),
latest_invoice_date AS (
  SELECT MAX(invoice_date) AS max_date FROM invoice
),
classified_customers AS (
  SELECT
    cf.customer_id, cf.first_purchase, cf.last_purchase,
    cf.total_orders, cf.total_spent, cf.avg_order_value, cf.avg_basket_size,
    CASE
      WHEN cf.first_purchase <= DATE_SUB(ld.max_date, INTERVAL 3 YEAR) THEN 'Long-Term'
      ELSE 'New'
    END AS customer_type
  FROM customer_first_last cf
  CROSS JOIN latest_invoice_date ld
)
SELECT
  customer_type,
  ROUND(AVG(total_orders), 2) AS avg_order_count,
  ROUND(AVG(total_spent), 2) AS avg_spending,
  ROUND(AVG(avg_order_value), 2) AS avg_order_value,
  ROUND(AVG(avg_basket_size), 2) AS avg_basket_size
FROM classified_customers
GROUP BY customer_type;

-- 4. Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?


-- Product Affinity (Genres)
WITH customer_genre_purchases AS (
  SELECT c.customer_id, g.name AS genre_name
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN genre g ON t.genre_id = g.genre_id
  GROUP BY c.customer_id, g.name
),

genre_pairs AS (
  SELECT a.genre_name AS genre1, b.genre_name AS genre2, COUNT(*) AS times_purchased_together
  FROM customer_genre_purchases a
  JOIN customer_genre_purchases b
    ON a.customer_id = b.customer_id AND a.genre_name < b.genre_name
  GROUP BY a.genre_name, b.genre_name
)

SELECT * FROM genre_pairs
ORDER BY times_purchased_together DESC
LIMIT 3;

-- Product Affinity(Artists)
WITH customer_artists AS (
  SELECT DISTINCT c.customer_id, ar.name AS artist_name
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN album al ON t.album_id = al.album_id
  JOIN artist ar ON al.artist_id = ar.artist_id
),
artist_combinations AS (
  SELECT
    a.artist_name AS artist1, b.artist_name AS artist2, COUNT(*) AS pair_count
  FROM customer_artists a
  JOIN customer_artists b
    ON a.customer_id = b.customer_id AND a.artist_name < b.artist_name
  GROUP BY a.artist_name, b.artist_name
)
SELECT * FROM artist_combinations
ORDER BY pair_count DESC
LIMIT 3;

-- Product Affinity(Albums)

WITH customer_albums AS (
  SELECT DISTINCT c.customer_id, al.title AS album_title
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN album al ON t.album_id = al.album_id
),
album_combinations AS (
  SELECT a.album_title AS album1, b.album_title AS album2, COUNT(*) AS pair_count
  FROM customer_albums a
  JOIN customer_albums b
    ON a.customer_id = b.customer_id AND a.album_title < b.album_title
  GROUP BY a.album_title, b.album_title
)
SELECT * FROM album_combinations
ORDER BY pair_count DESC
LIMIT 3;

-- 5. Come up Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?

WITH customer_stats AS (
  SELECT c.country, c.customer_id,
    COUNT(DISTINCT i.invoice_id) AS total_orders,
    SUM(il.unit_price * il.quantity) AS total_spent,
    MAX(i.invoice_date) AS last_purchase
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  GROUP BY c.country, c.customer_id
),
summary_per_country AS (
  SELECT country,
    ROUND(AVG(total_orders), 2) AS avg_order_count,
    ROUND(AVG(total_spent), 2) AS avg_spending,
    COUNT(*) AS total_customers,
    SUM(CASE 
          WHEN last_purchase < DATE_SUB((SELECT MAX(invoice_date) FROM invoice), INTERVAL 3 MONTH)
          THEN 1 ELSE 0
        END) AS churned_customers
  FROM customer_stats
  GROUP BY country
)
SELECT country, total_customers, churned_customers,
  ROUND((churned_customers / total_customers) * 100, 2) AS churn_rate_percent,
  avg_order_count,
  avg_spending
FROM summary_per_country
ORDER BY churn_rate_percent DESC;



-- 6. Which Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?

WITH customer_behavior AS (
  SELECT
    c.customer_id,
    c.country,
    COUNT(DISTINCT i.invoice_id) AS total_orders,
    SUM(il.unit_price * il.quantity) AS total_spent,
    MAX(i.invoice_date) AS last_purchase
  FROM customer c
  LEFT JOIN invoice i ON c.customer_id = i.customer_id
  LEFT JOIN invoice_line il ON i.invoice_id = il.invoice_id
  GROUP BY c.customer_id, c.country
),
churn_status AS (
  SELECT *,
    CASE
      WHEN last_purchase < DATE_SUB((SELECT MAX(invoice_date) FROM invoice), INTERVAL 3 MONTH)
      THEN 1 ELSE 0
    END AS is_churned
  FROM customer_behavior
)
SELECT
  country,
  COUNT(*) AS total_customers,
  SUM(is_churned) AS churned_customers,
  ROUND(AVG(total_orders), 2) AS avg_orders,
  ROUND(AVG(total_spent), 2) AS avg_spending,
  ROUND((SUM(is_churned) / COUNT(*)) * 100, 2) AS churn_rate_percent
FROM churn_status
GROUP BY country
ORDER BY churn_rate_percent DESC;


-- 7. Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predictthe lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristircs or purchase patterns among customers who have stopped purchasing?

WITH customer_metrics AS (
  SELECT
    c.customer_id,
    c.country,
    MIN(i.invoice_date) AS first_purchase,
    MAX(i.invoice_date) AS last_purchase,
    DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS tenure_days,
    COUNT(DISTINCT i.invoice_id) AS total_orders,
    SUM(il.unit_price * il.quantity) AS total_spent,
    ROUND(SUM(il.unit_price * il.quantity) / COUNT(DISTINCT i.invoice_id), 2) AS avg_order_value
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  GROUP BY c.customer_id, c.country
),
churn_labeled AS (
  SELECT *,
    CASE
      WHEN last_purchase < DATE_SUB((SELECT MAX(invoice_date) FROM invoice), INTERVAL 3 MONTH)
      THEN 1 ELSE 0
    END AS is_churned
  FROM customer_metrics
)
SELECT *
FROM churn_labeled
ORDER BY total_spent DESC;


-- 10. Explain How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?

ALTER TABLE album
ADD COLUMN ReleaseYear INT;
SELECT * FROM album;

-- 11. Chinook is interested in understanding the purchasing behaviour of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.

SELECT
  c.country,
  COUNT(DISTINCT c.customer_id) AS total_customers,
  ROUND(SUM(il.unit_price * il.quantity) / COUNT(DISTINCT c.customer_id), 2) AS avg_spent_per_customer,
  ROUND(SUM(il.quantity) / COUNT(DISTINCT c.customer_id), 2) AS avg_tracks_per_customer
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
GROUP BY c.country
ORDER BY avg_spent_per_customer DESC;

















