-- How many pizzas were ordered?

SELECT 
    count(pizza_id)
FROM customer_orders;

-- How many unique customer orders were made?

SELECT
    count( distinct order_id)
FROM customer_orders;

-- How many successful orders were delivered by each runner?

SELECT
    runner_id,
    count(order_id),
    CASE
        WHEN contains(cancellation, 'Cancellation') THEN 'Y'
        ELSE 'N'
    END as success
FROM runner_orders
WHERE success = 'N'
GROUP BY
    runner_id,
    success;

-- How many of each type of pizza was delivered?

SELECT
    pizza_name,
    count(c.pizza_id),
    CASE 
        WHEN contains(cancellation, 'Cancellation') THEN 'Y'
        ELSE 'N' 
    END as success
FROM 
    runner_orders as r
    JOIN customer_orders as c on r.order_id=c.order_id
    JOIN pizza_names as pn on pn.pizza_id = c.pizza_id
WHERE success = 'N'
GROUP BY 
    pizza_name,
    success;

-- How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
    customer_id,
    pizza_name,
    count(c.pizza_id)
FROM 
    runner_orders as r
    JOIN customer_orders as c on r.order_id=c.order_id
    JOIN pizza_names as pn on pn.pizza_id = c.pizza_id
GROUP BY 
    customer_id,
    pizza_name;

-- What was the maximum number of pizzas delivered in a single order?

SELECT
    order_id,
    count(pizza_id) as count
FROM customer_orders
GROUP BY order_id
ORDER BY count DESC
LIMIT 1;

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT
    customer_id,
    CASE 
        WHEN contains(cancellation, 'Cancellation') THEN 'N'
        ELSE 'Y' END as success,
    CASE 
        WHEN length(exclusions) = 0 
            AND (length(extras) = 0 OR extras IS NULL OR extras = 'null') THEN 'No Changes' 
        WHEN exclusions = 'null'
            AND (length(extras) = 0 OR extras IS NULL OR extras = 'null') THEN 'No Changes'
        ELSE 'Changed'
    END as tag,
    count(pizza_id)
FROM 
    customer_orders as c
    JOIN runner_orders as r on c.order_id=r.order_id
WHERE success = 'Y'
GROUP BY 
    customer_id,
    tag,
    success
ORDER BY customer_id;

-- How many pizzas were delivered that had both exclusions and extras?

SELECT
    CASE 
        WHEN length(exclusions) = 0 
            AND (length(extras) = 0 OR extras IS NULL OR extras = 'null') THEN 'No Changes' 
        WHEN exclusions = 'null'
            AND (length(extras) = 0 OR extras IS NULL OR extras = 'null') THEN 'No Changes'
        WHEN (length(exclusions) <> 0 AND exclusions <> 'null')
            AND (length(extras) <> 0 AND extras <> 'null' AND extras is not null) THEN 'Double Changes'
                ELSE 'Changed' END as tag,
    count(pizza_id) as count,
    CASE WHEN contains(cancellation, 'Cancellation') THEN 'Y'
    ELSE 'N' END as success
FROM 
    customer_orders as c
    JOIN runner_orders as r on c.order_id=r.order_id
GROUP BY 
    tag,
    success;

-- What was the total volume of pizzas ordered for each hour of the day?

SELECT 
    hour(order_time) as hour,
    count(pizza_id) as count
FROM customer_orders
GROUP BY hour;

-- What was the volume of orders for each day of the week?

SELECT 
    dayname(order_time) as day,
    count(pizza_id) as count
FROM customer_orders
GROUP BY day;

-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT
    week(dateadd(day,3,registration_date)) as newweek,
    --an offset was required to set the start of the week to 2021-01-01
    count(runner_id)
FROM runners
GROUP BY newweek;

-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT
    runner_id,
    avg(datediff(minute, order_time,pickup_time)) as pickupmin
FROM
    runner_orders as r
    JOIN customer_orders as c on r.order_id=c.order_id
WHERE pickup_time <> 'null'
GROUP BY runner_id;

-- Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT
    runner_id,
    r.order_id,
    count(pizza_id) as count,
    avg(datediff(minute, order_time,pickup_time)) as pickupmin,
    round(pickupmin/count, 1) as prep_time_per_pizza
FROM runner_orders as r
    JOIN customer_orders as c on r.order_id=c.order_id
WHERE pickup_time <> 'null'
GROUP BY 
    runner_id,
    r.order_id;

-- What was the average distance travelled for each customer?

SELECT 
    customer_id,
    avg(replace(distance,'km','')::numeric(3,1)) as dist
FROM customer_orders as c
    JOIN runner_orders as r on c.order_id=r.order_id
WHERE distance <> 'null'
GROUP BY customer_id;

-- What was the difference between the longest and shortest delivery times for all orders?

SELECT
    MAX(regexp_replace(duration, '[a-z]')::int)
    -MIN(regexp_replace(duration, '[a-z]')::int)
    as time
FROM runner_orders
where duration <> 'null';

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT
    runner_id,
    order_id,
    avg(round(((regexp_replace(distance, '[a-z]')::numeric(3,1))*1000)
    /((regexp_replace(duration, '[a-z]')::int)*60),4)) as speed
FROM runner_orders
WHERE duration <> 'null'
GROUP BY runner_id, order_id
ORDER BY runner_id;

-- What is the successful delivery percentage for each runner?

SELECT 
    runner_id,
        sum(CASE WHEN contains(cancellation, 'Cancellation')
        THEN 0 ELSE 1 END) as cancels,
    count(order_id) as total,
    cancels/total as rate
FROM runner_orders
GROUP BY runner_id;

-- What are the standard ingredients for each pizza?

SELECT
    topping_name,
    count(topping_name) as count
FROM pizza_recipes as t
    LEFT JOIN lateral split_to_table(toppings, ', ')
    JOIN pizza_toppings as p on value=p.topping_id
GROUP BY topping_name
HAVING count > 1;

-- What was the most commonly added extra?

SELECT
    topping_name,
    count(topping_name)
FROM customer_orders
    LEFT JOIN LATERAL split_to_table(extras, ', ')
    JOIN pizza_toppings on value = topping_id
WHERE extras <> 'null'
    AND extras is not null
    AND length(extras) > 0
GROUP BY topping_name;

-- What was the most common exclusion?

SELECT
    topping_name,
    count(topping_name)
FROM customer_orders
    LEFT JOIN LATERAL split_to_table(exclusions, ', ')
    JOIN pizza_toppings on value = topping_id
WHERE exclusions <> 'null'
    AND exclusions is not null
    AND length(exclusions) > 0
GROUP BY topping_name;

-- Generate an order item for each record in the customers_orders table in the format of one of the following:
    -- Meat Lovers
    -- Meat Lovers - Exclude Beef
    -- Meat Lovers - Extra Bacon
    -- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH EXT as (
    SELECT
        order_id,
        c.pizza_id,
        pizza_name,
        extras,
        listagg(distinct topping_name, ', ') as extra
    FROM customer_orders as c
        JOIN pizza_names as pn on c.pizza_id = pn.pizza_id
        LEFT JOIN LATERAL split_to_table(extras, ', ')
        JOIN pizza_toppings on value = topping_id
    WHERE extras <> 'null'
        AND extras is not null
        AND length(extras) > 0
    GROUP BY
        order_id,
        extras,
        pizza_name,
        c.pizza_id
    ORDER BY order_id
    )
, EXC as (
SELECT
    order_id,
    c.pizza_id,
    pizza_name,
    exclusions,
    listagg(distinct topping_name, ', ') as exclusion
FROM customer_orders as c
    JOIN pizza_names as pn on c.pizza_id = pn.pizza_id
    LEFT JOIN LATERAL split_to_table(exclusions, ', ')
    JOIN pizza_toppings on value = topping_id
WHERE exclusions <> 'null'
    AND exclusions is not null
    AND length(exclusions) > 0
GROUP BY 
    order_id, 
    exclusions,
    pizza_name,
    c.pizza_id
ORDER BY order_id
)
SELECT
    co.order_id,
    co.pizza_id,
    pn.pizza_name,
    concat(' - Extra ',extra) as extr,
    concat(' - Exclude ',exclusion) as excl,
    CASE WHEN extr is null and excl is null THEN pn.pizza_name
        WHEN extr is null and excl is not null THEN concat(pn.pizza_name,excl)
        WHEN extr is not null and excl is null THEN concat(pn.pizza_name,extr)
        ELSE concat(pn.pizza_name,extr,excl) END as FULL_NAME
FROM customer_orders as co
    LEFT JOIN EXT as e on 
    e.order_id = co.order_id and 
    e.pizza_id = co.pizza_id and
    e.extras = co.extras
    LEFT JOIN EXC as c on 
    c.order_id = co.order_id and 
    c.pizza_id = co.pizza_id and
    c.exclusions = co.exclusions
    JOIN pizza_names as pn on
    co.pizza_id = pn.pizza_id;