-- =========================================================
-- HOTEL RESERVATION & FLIGHT BOOKING SYSTEM
-- =========================================================

DROP SCHEMA IF EXISTS hotel_system CASCADE;
CREATE SCHEMA hotel_system;
SET search_path TO hotel_system;

-- =========================================================
-- 1) ROLES
-- =========================================================
CREATE TABLE roles (
    role_id      SERIAL PRIMARY KEY,
    role_name    VARCHAR(50) NOT NULL UNIQUE
);

-- =========================================================
-- 2) USERS
-- =========================================================
CREATE TABLE users (
    user_id        SERIAL PRIMARY KEY,
    full_name      VARCHAR(150) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    phone          VARCHAR(30) UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    role_id        INT NOT NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id)
        REFERENCES roles(role_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- =========================================================
-- 3) HOTELS
-- =========================================================
CREATE TABLE hotels (
    hotel_id        SERIAL PRIMARY KEY,
    hotel_name      VARCHAR(150) NOT NULL,
    location        VARCHAR(150) NOT NULL,
    star_rating     NUMERIC(2,1) NOT NULL CHECK (star_rating >= 1 AND star_rating <= 5),
    description     TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 4) ROOMS
-- =========================================================
CREATE TABLE rooms (
    room_id               SERIAL PRIMARY KEY,
    hotel_id              INT NOT NULL,
    room_number           VARCHAR(20) NOT NULL,
    room_type             VARCHAR(50) NOT NULL,
    capacity              INT NOT NULL CHECK (capacity > 0),
    price_per_night       NUMERIC(10,2) NOT NULL CHECK (price_per_night > 0),
    availability_status   VARCHAR(20) NOT NULL DEFAULT 'available'
                          CHECK (availability_status IN ('available', 'maintenance', 'inactive')),
    created_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rooms_hotel
        FOREIGN KEY (hotel_id)
        REFERENCES hotels(hotel_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT uq_room_number_per_hotel
        UNIQUE (hotel_id, room_number)
);

-- =========================================================
-- 5) HOTEL BOOKINGS
-- =========================================================
CREATE TABLE hotel_bookings (
    hotel_booking_id   SERIAL PRIMARY KEY,
    user_id            INT NOT NULL,
    room_id            INT NOT NULL,
    check_in_date      DATE NOT NULL,
    check_out_date     DATE NOT NULL,
    total_cost         NUMERIC(12,2) NOT NULL CHECK (total_cost >= 0),
    booking_status     VARCHAR(20) NOT NULL DEFAULT 'confirmed'
                       CHECK (booking_status IN ('confirmed', 'cancelled')),
    booking_date       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hotel_booking_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_hotel_booking_room
        FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_hotel_booking_dates
        CHECK (check_out_date > check_in_date)
);

-- Prevent overlapping confirmed bookings for the same room
CREATE OR REPLACE FUNCTION prevent_overlapping_hotel_bookings()
RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.booking_status = 'confirmed' THEN
        IF EXISTS (
            SELECT 1
            FROM hotel_bookings hb
            WHERE hb.room_id = NEW.room_id
              AND hb.booking_status = 'confirmed'
              AND hb.hotel_booking_id <> COALESCE(NEW.hotel_booking_id, 0)
              AND NEW.check_in_date < hb.check_out_date
              AND NEW.check_out_date > hb.check_in_date
        ) THEN
            RAISE EXCEPTION 'This room is already booked for the selected dates.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_overlapping_hotel_bookings
BEFORE INSERT OR UPDATE
ON hotel_bookings
FOR EACH ROW
EXECUTE FUNCTION prevent_overlapping_hotel_bookings();

-- =========================================================
-- 6) AIRLINES
-- =========================================================
CREATE TABLE airlines (
    airline_id      SERIAL PRIMARY KEY,
    airline_name    VARCHAR(150) NOT NULL UNIQUE,
    country         VARCHAR(100),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 7) FLIGHTS
-- =========================================================
CREATE TABLE flights (
    flight_id           SERIAL PRIMARY KEY,
    airline_id          INT NOT NULL,
    flight_number       VARCHAR(30) NOT NULL UNIQUE,
    departure_city      VARCHAR(100) NOT NULL,
    arrival_city        VARCHAR(100) NOT NULL,
    departure_time      TIMESTAMP NOT NULL,
    arrival_time        TIMESTAMP NOT NULL,
    price               NUMERIC(10,2) NOT NULL CHECK (price > 0),
    total_seats         INT NOT NULL CHECK (total_seats > 0),
    available_seats     INT NOT NULL CHECK (available_seats >= 0),
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_flights_airline
        FOREIGN KEY (airline_id)
        REFERENCES airlines(airline_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_flight_times
        CHECK (arrival_time > departure_time),

    CONSTRAINT chk_flight_cities
        CHECK (departure_city <> arrival_city),

    CONSTRAINT chk_available_seats
        CHECK (available_seats <= total_seats)
);

-- =========================================================
-- 8) FLIGHT BOOKINGS
-- =========================================================
CREATE TABLE flight_bookings (
    flight_booking_id   SERIAL PRIMARY KEY,
    user_id             INT NOT NULL,
    flight_id           INT NOT NULL,
    seat_number         VARCHAR(10) NOT NULL,
    total_cost          NUMERIC(12,2) NOT NULL CHECK (total_cost >= 0),
    booking_status      VARCHAR(20) NOT NULL DEFAULT 'confirmed'
                        CHECK (booking_status IN ('confirmed', 'cancelled')),
    booking_date        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_flight_booking_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_flight_booking_flight
        FOREIGN KEY (flight_id)
        REFERENCES flights(flight_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- Prevent double-booking same seat on same flight for confirmed bookings
CREATE UNIQUE INDEX uq_confirmed_flight_seat
ON flight_bookings (flight_id, seat_number)
WHERE booking_status = 'confirmed';

-- =========================================================
-- 9) PAYMENTS
-- =========================================================
CREATE TABLE payments (
    payment_id           SERIAL PRIMARY KEY,
    hotel_booking_id     INT,
    flight_booking_id    INT,
    payment_amount       NUMERIC(12,2) NOT NULL CHECK (payment_amount > 0),
    payment_method       VARCHAR(30) NOT NULL
                         CHECK (payment_method IN ('cash', 'credit_card', 'debit_card', 'wallet', 'bank_transfer')),
    payment_date         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payment_hotel_booking
        FOREIGN KEY (hotel_booking_id)
        REFERENCES hotel_bookings(hotel_booking_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_payment_flight_booking
        FOREIGN KEY (flight_booking_id)
        REFERENCES flight_bookings(flight_booking_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_payment_one_booking_only
        CHECK (
            (hotel_booking_id IS NOT NULL AND flight_booking_id IS NULL)
            OR
            (hotel_booking_id IS NULL AND flight_booking_id IS NOT NULL)
        )
);

-- One payment per booking
CREATE UNIQUE INDEX uq_payment_hotel_booking
ON payments (hotel_booking_id)
WHERE hotel_booking_id IS NOT NULL;

CREATE UNIQUE INDEX uq_payment_flight_booking
ON payments (flight_booking_id)
WHERE flight_booking_id IS NOT NULL;

-- =========================================================
-- 10) HOTEL REVIEWS
-- =========================================================
CREATE TABLE hotel_reviews (
    review_id        SERIAL PRIMARY KEY,
    user_id          INT NOT NULL,
    hotel_id         INT NOT NULL,
    rating           INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment          TEXT,
    review_date      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_review_hotel
        FOREIGN KEY (hotel_id)
        REFERENCES hotels(hotel_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT uq_user_hotel_review
        UNIQUE (user_id, hotel_id)
);

-- =========================================================
-- INDEXES FOR PERFORMANCE
-- =========================================================
CREATE INDEX idx_users_role_id
ON users(role_id);

CREATE INDEX idx_hotels_location
ON hotels(location);

CREATE INDEX idx_rooms_hotel_id
ON rooms(hotel_id);

CREATE INDEX idx_rooms_type
ON rooms(room_type);

CREATE INDEX idx_hotel_bookings_user_id
ON hotel_bookings(user_id);

CREATE INDEX idx_hotel_bookings_room_id
ON hotel_bookings(room_id);

CREATE INDEX idx_hotel_bookings_status
ON hotel_bookings(booking_status);

CREATE INDEX idx_hotel_bookings_dates
ON hotel_bookings(check_in_date, check_out_date);

CREATE INDEX idx_flights_airline_id
ON flights(airline_id);

CREATE INDEX idx_flights_route
ON flights(departure_city, arrival_city);

CREATE INDEX idx_flight_bookings_user_id
ON flight_bookings(user_id);

CREATE INDEX idx_flight_bookings_flight_id
ON flight_bookings(flight_id);

CREATE INDEX idx_flight_bookings_status
ON flight_bookings(booking_status);

CREATE INDEX idx_payments_method
ON payments(payment_method);

CREATE INDEX idx_hotel_reviews_hotel_id
ON hotel_reviews(hotel_id);

CREATE INDEX idx_hotel_reviews_user_id
ON hotel_reviews(user_id);

-- =========================================================
-- DATA INSERTION
-- =========================================================

-- ROLES
INSERT INTO roles (role_name) VALUES
('admin'),
('customer');

-- USERS
INSERT INTO users (full_name, email, phone, password_hash, role_id) VALUES
('Ahmed Hassan', 'ahmed@example.com', '01011111111', 'pass123', 2),
('Mona Ali', 'mona@example.com', '01022222222', 'pass123', 2),
('Omar Khaled', 'omar@example.com', '01033333333', 'pass123', 2),
('Sara Mostafa', 'sara@example.com', '01044444444', 'pass123', 2),
('Youssef Adel', 'youssef@example.com', '01055555555', 'pass123', 2),
('Laila Nabil', 'laila@example.com', '01066666666', 'pass123', 2),
('Karim Samir', 'karim@example.com', '01077777777', 'pass123', 2),
('Admin User', 'admin@example.com', '01000000000', 'adminpass', 1);

-- HOTELS
INSERT INTO hotels (hotel_name, location, star_rating, description) VALUES
('Nile View Hotel', 'Cairo', 4.5, 'Beautiful hotel overlooking the Nile'),
('Desert Oasis Resort', 'Giza', 4.0, 'Relaxing resort near pyramids'),
('Sea Breeze Hotel', 'Alexandria', 5.0, 'Luxury hotel by the sea'),
('Skyline Inn', 'Cairo', 3.8, 'Comfortable city hotel in downtown Cairo'),
('Palm Garden Hotel', 'Sharm El Sheikh', 4.7, 'Resort hotel near the beach'),
('Royal Lotus Hotel', 'Luxor', 4.2, 'Classic hotel near historic attractions');

-- ROOMS
INSERT INTO rooms (hotel_id, room_number, room_type, capacity, price_per_night) VALUES
(1, '101', 'Single', 1, 800),
(1, '102', 'Double', 2, 1200),
(1, '103', 'Suite', 4, 2500),
(1, '104', 'Double', 2, 1400),

(2, '201', 'Single', 1, 600),
(2, '202', 'Double', 2, 1000),
(2, '203', 'Suite', 3, 1800),

(3, '301', 'Double', 2, 1500),
(3, '302', 'Suite', 4, 3000),
(3, '303', 'Single', 1, 1100),

(4, '401', 'Single', 1, 700),
(4, '402', 'Double', 2, 950),
(4, '403', 'Suite', 3, 1700),

(5, '501', 'Double', 2, 1600),
(5, '502', 'Suite', 4, 3200),

(6, '601', 'Single', 1, 900),
(6, '602', 'Double', 2, 1300);

INSERT INTO hotel_bookings
(user_id, room_id, check_in_date, check_out_date, total_cost, booking_status, booking_date) VALUES
-- User 1: enough activity for history and spending queries
(1, 1, '2026-01-10', '2026-01-12', 1600, 'confirmed', '2026-01-01 10:00'),
(1, 2, '2026-02-05', '2026-02-08', 3600, 'confirmed', '2026-01-25 11:00'),
(1, 8, '2026-03-15', '2026-03-18', 4500, 'confirmed', '2026-03-01 09:30'),
(1, 14, '2026-05-10', '2026-05-13', 4800, 'confirmed', '2026-04-20 12:00'),

-- User 2: confirmed + cancelled
(2, 5, '2026-02-10', '2026-02-12', 1200, 'confirmed', '2026-02-01 10:30'),
(2, 12, '2026-04-02', '2026-04-05', 2850, 'confirmed', '2026-03-20 13:00'),
(2, 1, '2026-04-10', '2026-04-12', 1600, 'cancelled', '2026-03-25 08:00'),

-- User 3: repeated use of room 8 for room frequency
(3, 8, '2026-04-20', '2026-04-23', 4500, 'confirmed', '2026-04-01 15:00'),
(3, 8, '2026-05-01', '2026-05-04', 4500, 'confirmed', '2026-04-10 14:00'),
(3, 6, '2026-03-01', '2026-03-04', 3000, 'confirmed', '2026-02-15 16:00'),

-- User 4: current-day arrival + more bookings
(4, 9, CURRENT_DATE, CURRENT_DATE + 2, 6000, 'confirmed', CURRENT_DATE - INTERVAL '5 days'),
(4, 9, '2026-04-15', '2026-04-18', 9000, 'confirmed', '2026-03-30 18:00'),

-- User 5: cancellation behavior > 1
(5, 11, '2026-03-28', '2026-03-30', 1400, 'cancelled', '2026-03-10 09:00'),
(5, 13, '2026-04-07', '2026-04-10', 5100, 'cancelled', '2026-03-15 09:00'),
(5, 16, '2026-05-20', '2026-05-23', 2700, 'confirmed', '2026-05-01 10:00'),

-- User 6: back-to-back room bookings on room 3
(6, 3, '2026-06-01', '2026-06-03', 5000, 'confirmed', '2026-05-01 11:00'),
(7, 3, '2026-06-03', '2026-06-05', 5000, 'confirmed', '2026-05-02 12:00'),

-- User 7: more Cairo and Luxor activity
(7, 17, '2026-03-05', '2026-03-08', 3900, 'confirmed', '2026-02-20 12:30'),
(7, 4, '2026-04-01', '2026-04-04', 4200, 'confirmed', '2026-03-10 10:45'),

-- More activity to make monthly trends and room usage stronger
(2, 8, '2026-06-10', '2026-06-12', 3000, 'confirmed', '2026-05-18 14:20'),
(3, 8, '2026-06-20', '2026-06-22', 3000, 'confirmed', '2026-06-01 09:15'),
(6, 14, '2026-07-01', '2026-07-04', 4800, 'confirmed', '2026-06-10 13:40'),
(1, 6, '2026-07-10', '2026-07-13', 3000, 'confirmed', '2026-06-20 16:50'),
(4, 15, '2026-08-02', '2026-08-05', 9600, 'confirmed', '2026-07-15 11:25');

-- AIRLINES
INSERT INTO airlines (airline_name, country) VALUES
('EgyptAir', 'Egypt'),
('Emirates', 'UAE'),
('Qatar Airways', 'Qatar'),
('Saudia', 'Saudi Arabia');

-- FLIGHTS
INSERT INTO flights
(airline_id, flight_number, departure_city, arrival_city, departure_time, arrival_time, price, total_seats, available_seats) VALUES
(1, 'MS101', 'Cairo', 'Dubai', '2026-04-01 08:00', '2026-04-01 12:00', 5000, 150, 140),
(2, 'EK202', 'Dubai', 'Cairo', '2026-04-02 14:00', '2026-04-02 18:00', 5200, 150, 130),
(3, 'QR303', 'Cairo', 'Doha', '2026-04-03 10:00', '2026-04-03 13:00', 4500, 120, 110),
(1, 'MS404', 'Alexandria', 'Jeddah', '2026-04-05 09:00', '2026-04-05 11:30', 4000, 100, 90),
(4, 'SV505', 'Cairo', 'Riyadh', '2026-05-10 07:00', '2026-05-10 10:00', 4700, 180, 70),
(2, 'EK606', 'Cairo', 'Dubai', '2026-06-01 16:00', '2026-06-01 20:00', 5500, 160, 25);

-- FLIGHT BOOKINGS
INSERT INTO flight_bookings
(user_id, flight_id, seat_number, total_cost, booking_status, booking_date) VALUES
(1, 1, 'A1', 5000, 'confirmed', '2026-03-15 10:00'),
(2, 1, 'A2', 5000, 'confirmed', '2026-03-16 11:00'),
(3, 2, 'B1', 5200, 'confirmed', '2026-03-20 12:00'),
(4, 3, 'C1', 4500, 'confirmed', '2026-03-22 13:00'),
(1, 4, 'D1', 4000, 'confirmed', '2026-03-25 14:00'),
(2, 1, 'A3', 5000, 'cancelled', '2026-03-27 15:00'),
(5, 5, 'E1', 4700, 'confirmed', '2026-04-15 09:00'),
(6, 6, 'F1', 5500, 'confirmed', '2026-05-20 10:00'),
(7, 6, 'F2', 5500, 'confirmed', '2026-05-22 11:00');

-- PAYMENTS - HOTEL BOOKINGS
INSERT INTO payments (hotel_booking_id, payment_amount, payment_method, payment_date) VALUES
(1, 1600, 'credit_card', '2026-01-01 10:05'),
(2, 3600, 'cash', '2026-01-25 11:10'),
(3, 4500, 'wallet', '2026-03-01 09:40'),
(4, 4800, 'bank_transfer', '2026-04-20 12:05'),
(5, 1200, 'debit_card', '2026-02-01 10:40'),
(6, 2850, 'credit_card', '2026-03-20 13:05'),
(8, 4500, 'wallet', '2026-04-01 15:10'),
(9, 4500, 'cash', '2026-04-10 14:10'),
(10, 3000, 'credit_card', '2026-02-15 16:05'),
(11, 6000, 'bank_transfer', CURRENT_DATE - INTERVAL '4 days'),
(12, 9000, 'credit_card', '2026-03-30 18:05'),
(15, 2700, 'debit_card', '2026-05-01 10:05'),
(16, 5000, 'credit_card', '2026-05-01 11:05'),
(17, 5000, 'credit_card', '2026-05-02 12:05'),
(18, 3900, 'cash', '2026-02-20 12:35'),
(19, 4200, 'wallet', '2026-03-10 10:50'),
(20, 3000, 'credit_card', '2026-05-18 14:25'),
(21, 3000, 'cash', '2026-06-01 09:20'),
(22, 4800, 'bank_transfer', '2026-06-10 13:45'),
(23, 3000, 'debit_card', '2026-06-20 16:55'),
(24, 9600, 'credit_card', '2026-07-15 11:30');

-- PAYMENTS - FLIGHT BOOKINGS
INSERT INTO payments (flight_booking_id, payment_amount, payment_method, payment_date) VALUES
(1, 5000, 'credit_card', '2026-03-15 10:05'),
(2, 5000, 'cash', '2026-03-16 11:05'),
(3, 5200, 'wallet', '2026-03-20 12:05'),
(4, 4500, 'credit_card', '2026-03-22 13:05'),
(5, 4000, 'bank_transfer', '2026-03-25 14:05'),
(7, 4700, 'debit_card', '2026-04-15 09:05'),
(8, 5500, 'credit_card', '2026-05-20 10:05'),
(9, 5500, 'wallet', '2026-05-22 11:05');

-- HOTEL REVIEWS
INSERT INTO hotel_reviews (user_id, hotel_id, rating, comment, review_date) VALUES
(1, 1, 5, 'Amazing view and excellent service', '2026-01-13 12:00'),
(2, 1, 4, 'Very good stay overall', '2026-04-06 10:00'),
(3, 2, 4, 'Nice place and friendly staff', '2026-03-05 14:00'),
(4, 3, 5, 'Luxury experience', '2026-04-19 16:00'),
(1, 3, 5, 'Perfect stay by the sea', '2026-03-19 11:00'),
(5, 4, 3, 'Average cleanliness and slow service', '2026-03-31 09:30'),
(6, 4, 4, 'Good location but rooms are small', '2026-04-11 12:30'),
(7, 6, 4, 'Comfortable and close to attractions', '2026-03-09 13:00'),
(2, 6, 3, 'Service needs improvement', '2026-07-15 15:00'),
(3, 5, 5, 'Excellent resort and staff', '2026-05-15 18:00'),
(4, 5, 4, 'Great hotel and beach access', '2026-08-06 19:00');

-- =========================================================
--  QUICK CHECKS
-- =========================================================
SELECT * FROM hotel_bookings ORDER BY booking_date;
SELECT * FROM payments ORDER BY payment_date;
SELECT * FROM hotel_reviews ORDER BY review_date;
SELECT * FROM FLIGHT_BOOKINGS ORDER BY FLIGHT_ID;
SELECT * FROM AIRLINES; 
SELECT * FROM FLIGHTS;
SELECT * FROM HOTELS; 
SELECT * FROM ROLES; 
SELECT * FROM ROOMS; 
SELECT * FROM USERS; 
-- =========================================================
--  TRIGGER TEST
-- =========================================================
INSERT INTO hotel_system.hotel_bookings
(user_id, room_id, check_in_date, check_out_date, total_cost, booking_status, booking_date)
VALUES
(2, 3, '2026-06-02', '2026-06-04', 5000, 'confirmed', CURRENT_TIMESTAMP);
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- =========================================================
				-- RETURN QUERIES/REPORTS
-- =========================================================

SET search_path TO hotel_system;

-- =========================================================
-- CUSTOMER-SIDE QUERIES
-- =========================================================

-- =========================================================
-- 1) Available Hotel Rooms Search
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    h.location AS "City",
    h.star_rating AS "Hotel Rating",
    r.room_number AS "Room Number",
    r.room_type AS "Room Type",
    r.capacity AS "Capacity",
    r.price_per_night AS "Price Per Night"
FROM hotels h
JOIN rooms r
    ON h.hotel_id = r.hotel_id
WHERE h.location = 'Cairo'
  AND r.availability_status = 'available'
  AND NOT EXISTS (
      SELECT 1
      FROM hotel_bookings hb
      WHERE hb.room_id = r.room_id
        AND hb.booking_status = 'confirmed'
        AND DATE '2026-04-01' < hb.check_out_date
        AND DATE '2026-04-05' > hb.check_in_date
  )
ORDER BY h.star_rating DESC, r.price_per_night ASC;


-- =========================================================
-- 2) Filter and Compare Hotel Options
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    h.location AS "City",
    h.star_rating AS "Hotel Rating",
    r.room_type AS "Room Type",
    r.capacity AS "Capacity",
    r.price_per_night AS "Price Per Night"
FROM hotels h
JOIN rooms r
    ON h.hotel_id = r.hotel_id
WHERE r.availability_status = 'available'
  AND r.room_type = 'Double'
  AND r.price_per_night BETWEEN 800 AND 2000
  AND h.star_rating > (
      SELECT AVG(h2.star_rating)
      FROM hotels h2
  )
ORDER BY h.star_rating DESC, r.price_per_night ASC;


-- =========================================================
-- 3) Customer Booking History
-- =========================================================
SELECT
    u.full_name AS "Customer Name",
    'Hotel' AS "Booking Type",
    h.hotel_name AS "Booking Name",
    h.location AS "Destination",
    hb.booking_date AS "Booking Date",
    hb.check_in_date AS "Start Date",
    hb.check_out_date AS "End Date",
    hb.total_cost AS "Total Cost",
    hb.booking_status AS "Status"
FROM users u
JOIN hotel_bookings hb
    ON u.user_id = hb.user_id
JOIN rooms r
    ON hb.room_id = r.room_id
JOIN hotels h
    ON r.hotel_id = h.hotel_id
WHERE u.user_id = 2

UNION

SELECT
    u.full_name AS "Customer Name",
    'Flight' AS "Booking Type",
    f.flight_number AS "Booking Name",
    f.arrival_city AS "Destination",
    fb.booking_date AS "Booking Date",
    f.departure_time::date AS "Start Date",
    f.arrival_time::date AS "End Date",
    fb.total_cost AS "Total Cost",
    fb.booking_status AS "Status"
FROM users u
JOIN flight_bookings fb
    ON u.user_id = fb.user_id
JOIN flights f
    ON fb.flight_id = f.flight_id
WHERE u.user_id = 2;


-- =========================================================
-- 4) Booking Details with Payment Information
-- =========================================================
SELECT
    hb.hotel_booking_id AS "Booking ID",
    u.full_name AS "Customer Name",
    h.hotel_name AS "Hotel Name",
    h.location AS "City",
    r.room_number AS "Room Number",
    r.room_type AS "Room Type",
    hb.check_in_date AS "Check-In Date",
    hb.check_out_date AS "Check-Out Date",
    hb.total_cost AS "Booking Total",
    hb.booking_status AS "Booking Status",
    p.payment_amount AS "Payment Amount",
    p.payment_method AS "Payment Method",
    p.payment_date AS "Payment Date"
FROM hotel_bookings hb
JOIN users u
    ON hb.user_id = u.user_id
JOIN rooms r
    ON hb.room_id = r.room_id
JOIN hotels h
    ON r.hotel_id = h.hotel_id
JOIN payments p
    ON hb.hotel_booking_id = p.hotel_booking_id
WHERE hb.hotel_booking_id = 1;


-- =========================================================
-- 5) Flight Search by Route
-- =========================================================
SELECT
    a.airline_name AS "Airline",
    f.flight_number AS "Flight Number",
    f.departure_city AS "Departure City",
    f.arrival_city AS "Arrival City",
    f.departure_time AS "Departure Time",
    f.arrival_time AS "Arrival Time",
    f.price AS "Ticket Price",
    f.available_seats AS "Available Seats"
FROM flights f
JOIN airlines a
    ON f.airline_id = a.airline_id
WHERE f.departure_city = 'Cairo'
  AND f.arrival_city = 'Dubai'
  AND f.available_seats > 0
ORDER BY f.price ASC, f.departure_time ASC;


-- =========================================================
-- ADMIN / REPORTING QUERIES
-- =========================================================

-- =========================================================
-- 6) Hotel Booking Summary Report
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    h.location AS "City",
    COUNT(hb.hotel_booking_id) AS "Confirmed Bookings"
FROM hotels h
JOIN rooms r
    ON h.hotel_id = r.hotel_id
JOIN hotel_bookings hb
    ON r.room_id = hb.room_id
WHERE hb.booking_status = 'confirmed'
GROUP BY h.hotel_name, h.location
ORDER BY "Confirmed Bookings" DESC, "Hotel Name";


-- =========================================================
-- 7) Hotel Profitability Report
-- =========================================================
SELECT
    x."Hotel Name",
    x."Total Rooms",
    x."Total Revenue",
    x."Revenue Per Room",
    RANK() OVER (ORDER BY x."Revenue Per Room" DESC) AS "Profitability Rank"
FROM (
    SELECT
        h.hotel_name AS "Hotel Name",
        COUNT(DISTINCT r.room_id) AS "Total Rooms",
        SUM(hb.total_cost) AS "Total Revenue",
        SUM(hb.total_cost) / COUNT(DISTINCT r.room_id) AS "Revenue Per Room"
    FROM hotels h
    JOIN rooms r
        ON h.hotel_id = r.hotel_id
    JOIN hotel_bookings hb
        ON r.room_id = hb.room_id
    WHERE hb.booking_status = 'confirmed'
    GROUP BY h.hotel_name
) x
ORDER BY "Profitability Rank", "Hotel Name";


-- =========================================================
-- 8) Top Customers by Hotel Spending
-- =========================================================
SELECT
    x."Customer Name",
    x."Email",
    x."Phone",
    x."Confirmed Hotel Bookings",
    x."Total Hotel Spending",
    x."Average Spend per Booking",
    RANK() OVER (ORDER BY x."Total Hotel Spending" DESC) AS "Customer Rank"
FROM (
    SELECT
        u.full_name AS "Customer Name",
        u.email AS "Email",
        u.phone AS "Phone",
        COUNT(hb.hotel_booking_id) AS "Confirmed Hotel Bookings",
        SUM(hb.total_cost) AS "Total Hotel Spending",
        AVG(hb.total_cost) AS "Average Spend per Booking"
    FROM users u
    JOIN hotel_bookings hb
        ON u.user_id = hb.user_id
    WHERE hb.booking_status = 'confirmed'
    GROUP BY u.full_name, u.email, u.phone
) x
ORDER BY "Customer Rank", "Customer Name";


-- =========================================================
-- 9) Monthly Booking Trend Report
-- =========================================================
SELECT
    TRIM(TO_CHAR(booking_date, 'Month')) AS "Month Name",
    COUNT(hotel_booking_id) AS "Confirmed Hotel Bookings",
    SUM(total_cost) AS "Total Hotel Revenue",
    AVG(total_cost) AS "Average Booking Value"
FROM hotel_bookings
WHERE booking_status = 'confirmed'
GROUP BY TO_CHAR(booking_date, 'Month')
ORDER BY MIN(booking_date);


-- =========================================================
-- 10) Revenue by Payment Method Report
-- =========================================================
SELECT
    payment_method AS "Payment Method",
    COUNT(payment_id) AS "Number of Payments",
    SUM(payment_amount) AS "Total Revenue",
    AVG(payment_amount) AS "Average Payment Amount"
FROM payments
GROUP BY payment_method
ORDER BY "Total Revenue" DESC, "Payment Method";


-- =========================================================
-- OPERATIONAL QUERIES
-- =========================================================

-- =========================================================
-- 11) Today's Hotel Check-Ins
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    COUNT(hb.hotel_booking_id) AS "Number of Arrivals",
    ARRAY_AGG(u.full_name) AS "Arriving Guests"
FROM hotel_bookings hb
JOIN users u
    ON hb.user_id = u.user_id
JOIN rooms r
    ON hb.room_id = r.room_id
JOIN hotels h
    ON r.hotel_id = h.hotel_id
WHERE hb.check_in_date = CURRENT_DATE
  AND hb.booking_status = 'confirmed'
GROUP BY h.hotel_name
ORDER BY h.hotel_name;


-- =========================================================
-- 12) Rooms with High Booking Frequency
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    r.room_number AS "Room Number",
    r.room_type AS "Room Type",
    COUNT(hb.hotel_booking_id) AS "Confirmed Bookings"
FROM rooms r
JOIN hotels h
    ON r.hotel_id = h.hotel_id
JOIN hotel_bookings hb
    ON r.room_id = hb.room_id
WHERE hb.booking_status = 'confirmed'
GROUP BY h.hotel_name, r.room_number, r.room_type
HAVING COUNT(hb.hotel_booking_id) > (
    SELECT AVG(room_booking_count)
    FROM (
        SELECT COUNT(hb2.hotel_booking_id) AS room_booking_count
        FROM rooms r2
        JOIN hotel_bookings hb2
            ON r2.room_id = hb2.room_id
        WHERE hb2.booking_status = 'confirmed'
        GROUP BY r2.room_id
    ) sub
)
ORDER BY "Confirmed Bookings" DESC, "Hotel Name";


-- =========================================================
-- 13) Customers with High Cancellation Behavior
-- =========================================================
SELECT
    u.full_name AS "Customer Name",
    u.email AS "Email",
    u.phone AS "Phone",
    COUNT(hb.hotel_booking_id) AS "Cancelled Bookings"
FROM users u
JOIN hotel_bookings hb
    ON u.user_id = hb.user_id
WHERE hb.booking_status = 'cancelled'
GROUP BY u.full_name, u.email, u.phone
HAVING COUNT(hb.hotel_booking_id) > 1
ORDER BY "Cancelled Bookings" DESC, "Customer Name";


-- =========================================================
-- 14) Hotels with Low Ratings
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    h.location AS "City",
    AVG(hr.rating) AS "Average Guest Rating",
    COUNT(hr.review_id) AS "Number of Reviews"
FROM hotels h
JOIN hotel_reviews hr
    ON h.hotel_id = hr.hotel_id
GROUP BY h.hotel_name, h.location
HAVING AVG(hr.rating) < 4.5
ORDER BY "Average Guest Rating" ASC, "Hotel Name";


-- =========================================================
-- 15) Back-to-Back Room Bookings with No Buffer
-- =========================================================
SELECT
    h.hotel_name AS "Hotel Name",
    r.room_number AS "Room Number",
    r.room_type AS "Room Type",
    hb1.hotel_booking_id AS "Current Booking ID",
    hb1.check_out_date AS "Current Check-Out",
    hb2.hotel_booking_id AS "Next Booking ID",
    hb2.check_in_date AS "Next Check-In"
FROM hotel_bookings hb1
JOIN hotel_bookings hb2
    ON hb1.room_id = hb2.room_id
JOIN rooms r
    ON hb1.room_id = r.room_id
JOIN hotels h
    ON r.hotel_id = h.hotel_id
WHERE hb1.hotel_booking_id <> hb2.hotel_booking_id
  AND hb1.booking_status = 'confirmed'
  AND hb2.booking_status = 'confirmed'
  AND hb1.check_out_date = hb2.check_in_date
ORDER BY h.hotel_name, r.room_number, hb1.check_out_date;