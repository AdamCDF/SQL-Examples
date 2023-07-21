--What is the total amount each customer spent at the restaurant?
SELECT customer_id,
    SUM(price)
FROM sales as s
    JOIN menu as m on s.product_id = m.product_id
GROUP BY customer_id;
-- How many days has each customer visited the restaurant?
SELECT customer_id,
    count(distinct order_date)
FROM sales
GROUP BY customer_id;
-- What was the first item from the menu purchased by each customer?
SELECT customer_id,
    min(order_date),
    min(product_name)
FROM sales as s
    JOIN menu as m ON s.product_id = m.product_id
GROUP BY customer_id;
-- What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT s.product_id,
    count(s.product_id) as count,
    min(product_name) as name
FROM sales as s
    JOIN menu as m ON m.product_id = s.product_id
GROUP BY s.product_id
ORDER BY count DESC
LIMIT 1;
-- Which item was the most popular for each customer?
WITH CTE AS (
    SELECT customer_id,
        min(product_name) as name,
        count(s.product_id) as count,
        rank() over(
            partition by customer_id
            order by count DESC
        ) as rnk
    FROM sales as s
        JOIN menu as m on s.product_id = m.product_id
    GROUP BY customer_id,
        s.product_id
    ORDER BY customer_id,
        s.product_id
)
SELECT *
FROM CTE
WHERE rnk = 1;
-- Which item was purchased first by the customer after they became a member?
WITH CTE AS (
    SELECT m.customer_id,
        join_date,
        order_date,
        product_id,
        rank() over (
            partition by m.customer_id
            order by order_date
        ) as rnk
    FROM members as m
        JOIN sales as s on m.customer_id = s.customer_id
    WHERE join_date < order_date
)
SELECT *
FROM CTE
    JOIN menu as mn on mn.product_id = cte.product_id
WHERE rnk = 1;
-- Which item was purchased just before the customer became a member?
WITH CTE AS (
    SELECT m.customer_id,
        join_date,
        order_date,
        product_id,
        rank() over (
            partition by m.customer_id
            order by order_date DESC
        ) as rnk
    FROM members as m
        JOIN sales as s on m.customer_id = s.customer_id
    WHERE join_date > order_date
)
SELECT *
FROM CTE
    JOIN menu as mn on mn.product_id = cte.product_id
WHERE rnk = 1;
-- What is the total items and amount spent for each member before they became a member?
SELECT m.customer_id,
    COUNT(s.product_id),
    sum(price)
FROM members as m
    JOIN sales as s on m.customer_id = s.customer_id
    JOIN menu as mn on mn.product_id = s.product_id
WHERE join_date > order_date
GROUP BY m.customer_id;
-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT customer_id,
    sum(
        CASE
            WHEN product_name = 'sushi' THEN (price * 20)
            ELSE price * 10
        END
    ) as score
FROM sales as s
    JOIN menu as m on m.product_id = s.product_id
GROUP BY customer_id;
-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH CTE AS (
    SELECT s.customer_id,
        order_date,
        join_date,
        dateadd(day, 6, join_date) as oneweekon,
        product_name,
        price,
        CASE
            WHEN join_date <= order_date
            AND oneweekon >= order_date THEN 2
            WHEN product_name = 'sushi' THEN 2
            ELSE 1
        END as tag
    FROM members as m
        JOIN sales as s on m.customer_id = s.customer_id
        JOIN menu as mn on mn.product_id = s.product_id
    WHERE month(order_date) = 1
)
SELECT customer_id,
    sum(price * tag * 10) as score
FROM CTE
GROUP BY customer_id;