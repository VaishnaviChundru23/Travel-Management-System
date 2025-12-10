--PSM

-- Trigger
USE TourismGroup8;

-- 1
-- Dynamic Discount Allocation for Itinerary Bookings
-- Trigger to apply dynamic discounts based on the total cost of an itinerary. If the total cost exceeds a specific amount, apply a discount automatically.


CREATE TRIGGER trg_ApplyDiscountOnBooking
ON Booking
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @BookingID INT, @TotalCost FLOAT;

    SELECT @BookingID = Booking_ID, @TotalCost = Total_Cost
    FROM inserted;

    IF @TotalCost > 5000 AND @TotalCost <= 10000
    BEGIN
        UPDATE Booking
        SET Total_Cost = Total_Cost * 0.95 -- 5% discount
        WHERE Booking_ID = @BookingID;
    END
    ELSE IF @TotalCost > 10000
    BEGIN
        UPDATE Booking
        SET Total_Cost = Total_Cost * 0.90 -- 10% discount
        WHERE Booking_ID = @BookingID;
    END
END;
GO

--TEST

select * from Booking

-- Cascade Price Updates for Activities
-- Trigger to automatically recalculate the total cost in Itinerary when the price of an Activity changes

CREATE OR ALTER TRIGGER trg_UpdateItineraryTotalCost
ON Activity
AFTER UPDATE
AS
BEGIN
    IF UPDATE(Price)
    BEGIN
        UPDATE Itinerary
        SET Total_Cost = Total_Cost + (
            SELECT SUM(i.Price) - SUM(d.Price) -- Explicitly qualify the column names
            FROM inserted i
            JOIN deleted d ON i.Activity_ID = d.Activity_ID
            WHERE i.Activity_ID IN (
                SELECT b.Activity_ID
                FROM Booking b
                WHERE b.Itinerary_ID = Itinerary.Itinerary_ID
            )
        )
        WHERE Itinerary_ID IN (
            SELECT b.Itinerary_ID
            FROM Booking b
            WHERE b.Activity_ID IN (SELECT i.Activity_ID FROM inserted i)
        );
    END
END;
GO

--TEST

UPDATE Activity
SET Price = 120 
WHERE Activity_ID = 1;


SELECT * FROM Itinerary;


-- Track Payment Status Changes
-- Trigger to log changes in the payment status to an audit table for tracking and analysis.
CREATE TRIGGER trg_LogPaymentStatusChange
ON Payment
AFTER UPDATE
AS
BEGIN
    IF UPDATE(Payment_Status)
    BEGIN
        INSERT INTO Payment_Audit (Payment_ID, Old_Status, New_Status, Changed_At)
        SELECT d.Payment_ID, d.Payment_Status AS Old_Status, i.Payment_Status AS New_Status, GETDATE() AS Changed_At
        FROM deleted d
        JOIN inserted i ON d.Payment_ID = i.Payment_ID;
    END
END;
GO

-- Audit Table Definition
CREATE TABLE Payment_Audit (
    Audit_ID INT IDENTITY(1,1) PRIMARY KEY,
    Payment_ID INT NOT NULL,
    Old_Status VARCHAR(50),
    New_Status VARCHAR(50),
    Changed_At DATETIME DEFAULT GETDATE()
);

--TEST

UPDATE Payment 
SET Payment_Status = 'Failed' 
WHERE Payment_ID = 5;



-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Stored Procedures with Input and Output Parameters

-- Get Total Booking Cost by User
-- This procedure calculates the total booking cost for a specific user.

CREATE PROCEDURE GetTotalBookingCostByUser
    @UserID INT,
    @TotalCost FLOAT OUTPUT
AS
BEGIN
    SELECT @TotalCost = SUM(Total_Cost)
    FROM Booking
    WHERE User_ID = @UserID;
END;
GO

-- Test 

DECLARE @TotalCost FLOAT;
EXEC GetTotalBookingCostByUser @UserID = 1, @TotalCost = @TotalCost OUTPUT;
PRINT @TotalCost;


-- Add a New Tourist Destination
-- This procedure inserts a new tourist destination.

CREATE PROCEDURE AddTouristDestination
    @AgencyID INT,
    @Name VARCHAR(100),
    @Location VARCHAR(100),
    @PopularAttractions VARCHAR(500),
    @Rating INT,
    @DestinationID INT OUTPUT
AS
BEGIN
    INSERT INTO Tourist_Destination (Agency_ID, Name, Location, Popular_Attractions, Rating)
    VALUES (@AgencyID, @Name, @Location, @PopularAttractions, @Rating);

    SET @DestinationID = SCOPE_IDENTITY();
END;
GO

-- Test
DECLARE @DestinationID INT;
EXEC AddTouristDestination @AgencyID = 1, @Name = 'Grand Canyon', @Location = 'Arizona',
                           @PopularAttractions = 'Hiking, Scenic Views', @Rating = 5, 
                           @DestinationID = @DestinationID OUTPUT;
PRINT @DestinationID;


-- Update Payment Status
-- This procedure updates the payment status for a booking and outputs the updated status.

CREATE PROCEDURE UpdatePaymentStatus
    @PaymentID INT,
    @NewStatus VARCHAR(50),
    @UpdatedStatus VARCHAR(50) OUTPUT
AS
BEGIN
    UPDATE Payment
    SET Payment_Status = @NewStatus
    WHERE Payment_ID = @PaymentID;

    SELECT @UpdatedStatus = Payment_Status
    FROM Payment
    WHERE Payment_ID = @PaymentID;
END;
GO

-- Test
DECLARE @UpdatedStatus VARCHAR(50);
EXEC UpdatePaymentStatus @PaymentID = 1, @NewStatus = 'Paid', @UpdatedStatus = @UpdatedStatus OUTPUT;
PRINT @UpdatedStatus;

---------------------------------------------------------------------------------------------------------------------------------------------------


-- Views for Reporting

-- Active Bookings
-- Displays all active bookings with user details.

CREATE VIEW ActiveBookings AS
SELECT b.Booking_ID, u.Name AS UserName, b.Booking_Date, b.Total_Cost, b.Payment_Status
FROM Booking b
JOIN [User] u ON b.User_ID = u.User_ID
WHERE b.Payment_Status = 'Pending';
GO

-- Test 
SELECT * FROM ActiveBookings;


-- Destination Ratings
-- Summarizes average ratings of destinations grouped by agency.

CREATE VIEW DestinationRatings AS
SELECT a.Name AS AgencyName, td.Name AS DestinationName, AVG(r.Rating) AS AverageRating
FROM Tourist_Destination td
JOIN Travel_Agency a ON td.Agency_ID = a.Agency_ID
JOIN Review r ON td.Destination_ID = r.Destination_ID
GROUP BY a.Name, td.Name;
GO

-- Test
SELECT * FROM DestinationRatings;


-- User Itineraries
-- Shows user itineraries with destination and cost details.

CREATE VIEW UserItineraries AS
SELECT i.Itinerary_ID, u.Name AS UserName, i.Start_Date, i.End_Date, i.Destination, i.Total_Cost
FROM Itinerary i
JOIN [User] u ON i.User_ID = u.User_ID;
GO

-- Test

SELECT * FROM UserItineraries;

----------------------------------------------------------------------------------------------------------------------------------------------------

-- User-Defined Functions

-- Get Average Accommodation Rating
-- Returns the average rating for a specific accommodation.

CREATE FUNCTION GetAverageAccommodationRating(@AccommodationID INT)
RETURNS FLOAT
AS
BEGIN
    RETURN (
        SELECT AVG(CAST(Rating AS FLOAT))
        FROM Review
        WHERE Accommodation_ID = @AccommodationID
    );
END;
GO

-- Test

SELECT dbo.GetAverageAccommodationRating(1);

-- Calculate Booking Duration
-- Returns the number of days between booking start and end dates.

CREATE FUNCTION CalculateBookingDuration(@StartDate DATETIME, @EndDate DATETIME)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, @StartDate, @EndDate);
END;
GO

-- Test

SELECT dbo.CalculateBookingDuration('2023-12-01', '2023-12-10');

-- Check Guide Availability
-- Returns 1 if a guide is available during a specific date range.

CREATE FUNCTION CheckGuideAvailability(@GuideID INT, @StartDate DATETIME, @EndDate DATETIME)
RETURNS BIT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Guide_Contract
        WHERE Guide_ID = @GuideID
          AND ContractStartDate <= @EndDate
          AND ContractEndDate >= @StartDate
    )
        RETURN 0;
    RETURN 1;
END;
GO

-- Test

SELECT dbo.CheckGuideAvailability(1, '2023-12-01', '2023-12-10');

