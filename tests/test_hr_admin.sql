/*

-- Check employee contract before creating a new one
SELECT employee_id, contract_id 
FROM Employee 
WHERE employee_id = 1;

-- List all existing contracts before
SELECT * FROM Contract ORDER BY contract_id;

-- Check subtype table before (FullTime example)
SELECT * FROM FullTimeContract ORDER BY contract_id;

EXEC CreateContract 
    @EmployeeID = 1,
    @Type = 'FullTime',
    @StartDate = '2025-01-01',
    @EndDate = '2025-12-31';

-- Employee should now reference new contract
SELECT employee_id, contract_id 
FROM Employee 
WHERE employee_id = 1;

-- New contract should exist
SELECT * FROM Contract WHERE contract_id = 4;

-- Subtype table must also contain new entry
SELECT * FROM FullTimeContract WHERE contract_id = 4;
*/
/*



-- 2 RenewContract
-- Before
SELECT * FROM Contract WHERE contract_id = 1;

-- Test RenewContract
EXEC RenewContract 1, '2026-01-01';

-- After
SELECT * FROM Contract WHERE contract_id = 1;
*/



-- 3 ApproveLeaveRequest
/*
-- Check the leave request before approval
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;   -- Example request (Sara’s Sick Leave)

-- Check subtype (VacationLeave) - should NOT change for sick leave
SELECT * FROM VacationLeave;

-- Check notifications before
SELECT * FROM Notification ORDER BY notification_id;

-- Check employee_notification before
SELECT * FROM Employee_Notification WHERE employee_id = 2;
EXEC ApproveLeaveRequest 
    @LeaveRequestID = 2,
    @ApproverID = 1,
    @Status = 'Approved';
    -- 1. Leave request should now be updated
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;

-- 2. Notification should now include the new message
SELECT TOP 1 * 
FROM Notification 
ORDER BY notification_id DESC;

-- 3. Employee_Notification should now have one row for employee 2
SELECT * 
FROM Employee_Notification
WHERE employee_id = 2;
*/
