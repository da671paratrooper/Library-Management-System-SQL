/* 
Library Management System (Beginner-friendly version)
A.2 Team Project

Notes:
- This script creates a small library database with 3 tables:
  1) Books
  2) Borrowers
  3) Transactions (borrowing history)

- Then it inserts sample data.
- Finally it runs the required queries for:
  - availability
  - overdue books
  - popular genres
  - JOIN borrower + borrowed books

Tip: Run the whole script once. If you need to re-run, it will drop and recreate the DB.
*/

------------------------------------------------------------
-- 1) Start fresh (drop DB if it already exists)
------------------------------------------------------------
IF DB_ID('LibraryManagementDB') IS NOT NULL
BEGIN
    ALTER DATABASE LibraryManagementDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LibraryManagementDB;
END;
GO

------------------------------------------------------------
-- 2) Create the database
------------------------------------------------------------
CREATE DATABASE LibraryManagementDB;
GO

USE LibraryManagementDB;
GO

------------------------------------------------------------
-- 3) Create tables
------------------------------------------------------------

-- Books table: basic book info + how many copies we own
CREATE TABLE dbo.Books
(
    BookID       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Title        VARCHAR(200) NOT NULL,
    Author       VARCHAR(120) NOT NULL,
    Genre        VARCHAR(50)  NOT NULL,
    TotalCopies  INT NOT NULL,
    CONSTRAINT CK_Books_TotalCopies CHECK (TotalCopies >= 0)
);
GO

-- Borrowers table: basic borrower info
CREATE TABLE dbo.Borrowers
(
    BorrowerID   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    FirstName    VARCHAR(50) NOT NULL,
    LastName     VARCHAR(50) NOT NULL,
    Email        VARCHAR(120) NULL,
    Phone        VARCHAR(30)  NULL
);
GO

/* 
Transactions table:
- One row per borrowing transaction.
- ReturnDate is NULL until the book is returned.
*/
CREATE TABLE dbo.Transactions
(
    TransactionID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    BookID        INT NOT NULL,
    BorrowerID    INT NOT NULL,
    BorrowDate    DATE NOT NULL,
    ReturnDate    DATE NULL,

    CONSTRAINT FK_Transactions_Books
        FOREIGN KEY (BookID) REFERENCES dbo.Books(BookID),

    CONSTRAINT FK_Transactions_Borrowers
        FOREIGN KEY (BorrowerID) REFERENCES dbo.Borrowers(BorrowerID),

    -- ReturnDate can be NULL, but if it exists it should not be before BorrowDate
    CONSTRAINT CK_Transactions_ReturnDate
        CHECK (ReturnDate IS NULL OR ReturnDate >= BorrowDate)
);
GO

------------------------------------------------------------
-- 4) Insert sample data
------------------------------------------------------------

-- Sample books
INSERT INTO dbo.Books (Title, Author, Genre, TotalCopies) VALUES
('The Hobbit', 'J.R.R. Tolkien', 'Fantasy', 3),
('1984', 'George Orwell', 'Dystopian', 2),
('The Martian', 'Andy Weir', 'Science Fiction', 2),
('The Alchemist', 'Paulo Coelho', 'Fiction', 1),
('Educated', 'Tara Westover', 'Memoir', 2),
('Dune', 'Frank Herbert', 'Science Fiction', 3);
GO

-- Sample borrowers
INSERT INTO dbo.Borrowers (FirstName, LastName, Email, Phone) VALUES
('John', 'Camacho', 'john@example.com', '555-0101'),
('Brianna', 'Camacho', 'brianna@example.com', '555-0102'),
('Alex', 'Nguyen', 'alex@example.com', '555-0103'),
('Sofia', 'Garcia', 'sofia@example.com', '555-0104');
GO

/* 
Sample transactions:
- Some returned, some not returned (ReturnDate = NULL)
- Some are overdue (borrowed more than 14 days ago and not returned)
*/
INSERT INTO dbo.Transactions (BookID, BorrowerID, BorrowDate, ReturnDate) VALUES
-- Returned books
(1, 1, DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), DATEADD(DAY, -20, CAST(GETDATE() AS DATE))),
(2, 2, DATEADD(DAY, -10, CAST(GETDATE() AS DATE)), DATEADD(DAY, -5,  CAST(GETDATE() AS DATE))),

-- Not returned (current loans)
(3, 3, DATEADD(DAY, -3,  CAST(GETDATE() AS DATE)), NULL),
(4, 4, DATEADD(DAY, -8,  CAST(GETDATE() AS DATE)), NULL),

-- Overdue (not returned, borrowed > 14 days ago)
(5, 1, DATEADD(DAY, -25, CAST(GETDATE() AS DATE)), NULL),
(6, 2, DATEADD(DAY, -18, CAST(GETDATE() AS DATE)), NULL);
GO

------------------------------------------------------------
-- 5) REQUIRED QUERIES
------------------------------------------------------------

/*
Requirement A: Track book availability.
Idea:
- For each book, count how many copies are currently checked out.
- AvailableCopies = TotalCopies - CheckedOutCopies
*/
SELECT
    b.BookID,
    b.Title,
    b.Author,
    b.Genre,
    b.TotalCopies,
    -- how many of this book are currently out (ReturnDate is NULL)
    CheckedOutCopies = COUNT(t.TransactionID),
    AvailableCopies  = b.TotalCopies - COUNT(t.TransactionID)
FROM dbo.Books b
LEFT JOIN dbo.Transactions t
    ON b.BookID = t.BookID
   AND t.ReturnDate IS NULL
GROUP BY b.BookID, b.Title, b.Author, b.Genre, b.TotalCopies
ORDER BY b.Title;
GO

/*
Requirement B: Identify overdue books.
Assumption:
- A book is overdue if it's been out more than 14 days and not returned.
*/
SELECT
    t.TransactionID,
    b.Title,
    br.FirstName,
    br.LastName,
    t.BorrowDate,
    DaysOut = DATEDIFF(DAY, t.BorrowDate, CAST(GETDATE() AS DATE))
FROM dbo.Transactions t
INNER JOIN dbo.Books b
    ON t.BookID = b.BookID
INNER JOIN dbo.Borrowers br
    ON t.BorrowerID = br.BorrowerID
WHERE t.ReturnDate IS NULL
  AND DATEDIFF(DAY, t.BorrowDate, CAST(GETDATE() AS DATE)) > 14
ORDER BY DaysOut DESC;
GO

/*
Requirement C: Report popular genres.
Idea:
- Count borrow transactions by Genre.
- You can count all transactions (returned + not returned),
  because it still shows what gets borrowed most.
*/
SELECT
    b.Genre,
    TimesBorrowed = COUNT(t.TransactionID)
FROM dbo.Transactions t
INNER JOIN dbo.Books b
    ON t.BookID = b.BookID
GROUP BY b.Genre
ORDER BY TimesBorrowed DESC, b.Genre;
GO

/*
Requirement D: Join borrower info with borrowed books.
This shows current loans (ReturnDate is NULL).
*/
SELECT
    br.BorrowerID,
    br.FirstName,
    br.LastName,
    b.BookID,
    b.Title,
    t.BorrowDate
FROM dbo.Transactions t
INNER JOIN dbo.Borrowers br
    ON t.BorrowerID = br.BorrowerID
INNER JOIN dbo.Books b
    ON t.BookID = b.BookID
WHERE t.ReturnDate IS NULL
ORDER BY t.BorrowDate DESC;
GO
