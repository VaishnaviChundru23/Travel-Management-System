ALTER TABLE [User]
ADD EncryptedPassword VARBINARY(MAX);

-- Drop the symmetric key if it exists
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'TourismSymmetricKey')
    DROP SYMMETRIC KEY TourismSymmetricKey;

-- Drop the certificate if it exists
IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'TourismCert')
    DROP CERTIFICATE TourismCert;

-- Drop the master key if it exists
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
    DROP MASTER KEY;

-- Step 1: Create a Symmetric Key and Certificate
USE TourismGroup8;

-- Create a master key if it doesn't already exist
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword!123';

-- Create a certificate to encrypt the symmetric key
CREATE CERTIFICATE TourismCert
WITH SUBJECT = 'Encryption Certificate for TourismGroup8';

-- Create a symmetric key for encryption
CREATE SYMMETRIC KEY TourismSymmetricKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE TourismCert;

-- Step 2: Encrypt the Password column
-- Open the symmetric key
OPEN SYMMETRIC KEY TourismSymmetricKey
DECRYPTION BY CERTIFICATE TourismCert;


-- Encrypt the Password column and store it in the new EncryptedPassword column
UPDATE [User]
SET EncryptedPassword = EncryptByKey(Key_GUID('TourismSymmetricKey'), CONVERT(VARBINARY(MAX), Password));

-- Close the symmetric key
CLOSE SYMMETRIC KEY TourismSymmetricKey;

SELECT User_ID, Name, EncryptedPassword
FROM [User];

---------------Decryption-------------------
-- Open the symmetric key
OPEN SYMMETRIC KEY TourismSymmetricKey
DECRYPTION BY CERTIFICATE TourismCert;

-- Decrypt the Password column to verify data
SELECT [User_ID], [Name], 
       CONVERT(VARCHAR(MAX), DecryptByKey(EncryptedPassword)) AS Decrypted_Password
FROM [User];

select * from [User];



-- Close the symmetric key
CLOSE SYMMETRIC KEY TourismSymmetricKey;

SELECT User_ID, Name, Password AS Encrypted_Password
FROM [User];


SELECT User_ID, Name, Password
FROM [User]
WHERE Password IS NULL;

SELECT User_ID, Name, Password AS Encrypted_Password
FROM [User]
WHERE Password IS NOT NULL;





