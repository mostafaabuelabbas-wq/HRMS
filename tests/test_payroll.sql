/*
EXEC GeneratePayroll '2024-03-01', '2024-03-31';
EXEC GeneratePayroll '2024-03-01', '2024-03-31
*/

/*
-- Check payroll row
SELECT payroll_id, employee_id, base_amount, taxes, contributions, adjustments, actual_pay, net_salary
FROM Payroll
WHERE payroll_id = 1;   -- assuming @p1 = 1

-- Check existing allowance/deductions
SELECT ad_id, payroll_id, employee_id, type, amount, currency_code, duration, timezone
FROM AllowanceDeduction
WHERE payroll_id = 1;

EXEC AdjustPayrollItem
     @PayrollID = 1,
     @Type = 'Bonus',
     @Amount = 1000,
     @Duration = 60,
     @Timezone = 'EET';

     -- Payroll should be recalculated
SELECT payroll_id, employee_id, base_amount, taxes, contributions, adjustments, actual_pay, net_salary
FROM Payroll
WHERE payroll_id = 1;

-- Allowance/Deduction updated list
SELECT ad_id, payroll_id, employee_id, type, amount, currency_code, duration, timezone
FROM AllowanceDeduction
WHERE payroll_id = 1;
*/
/*
DECLARE @N DECIMAL(10,2);

EXEC CalculateNetSalary
    @PayrollID = 1,
    @NetSalary = @N OUTPUT;

SELECT @N AS ReturnedNetSalary;
*/

/*
-- TEST 1
SELECT * FROM PayrollPolicy_ID WHERE payroll_id = 1;

EXEC ApplyPayrollPolicy 
    @PolicyID = 1,
    @PayrollID = 1,
    @Type = 'General',
    @Description = 'General payroll rules';

-- TEST 2
SELECT * FROM PayrollPolicy_ID WHERE payroll_id = 1;

EXEC ApplyPayrollPolicy
    @PolicyID = 2,
    @PayrollID = 1,
    @Type = 'Overtime',
    @Description = 'Overtime multipliers';

SELECT * FROM PayrollPolicy_ID WHERE payroll_id = 1;


EXEC GetMonthlyPayrollSummary
    @Month = 3,
    @Year = 2024;
   

    EXEC GetEmployeePayrollHistory @EmployeeID = 1;
     

EXEC GetBonusEligibleEmployees @Eligibility_criteria = 'rating';

SELECT employee_id, salary_type_id
FROM Employee
WHERE employee_id = 1;

EXEC UpdateSalaryType
    @EmployeeID = 1,
    @SalaryTypeID = 3;

    SELECT employee_id, salary_type_id
FROM Employee
WHERE employee_id = 1;


EXEC GetPayrollByDepartment
    @DepartmentID = 1,
    @Month = 2,
    @Year = 2024;

    
    EXEC ValidateAttendanceBeforePayroll @PayrollPeriodID = 1;

   
EXEC ValidateAttendanceBeforePayroll @PayrollPeriodID = 1;

 
 SELECT * FROM AllowanceDeduction WHERE type = 'Attendance Adjustment';
 
 EXEC SyncAttendanceToPayroll @SyncDate = '2024-02-05';

 SELECT payroll_id, employee_id, type, amount, duration, currency_code
FROM AllowanceDeduction
WHERE type = 'Attendance Adjustment';



EXEC SyncApprovedPermissionsToPayroll @PayrollPeriodID = 1;
SELECT payroll_id, employee_id, type, amount, duration, currency_code
FROM AllowanceDeduction
WHERE type = 'Leave Deduction';


SELECT * FROM PayGrade WHERE grade_name = 'Expert';

EXEC ConfigurePayGrades 
    @GradeName = 'Expert',
    @MinSalary = 30000,
    @MaxSalary = 50000;

SELECT * FROM PayGrade WHERE grade_name = 'Expert';



SELECT * FROM AllowanceDeduction WHERE type = 'Shift Allowance';

EXEC ConfigureShiftAllowances
     @ShiftType = 'Fixed',
     @AllowanceName = 'Shift Allowance',
     @Amount = 300;

     SELECT payroll_id, employee_id, type, amount, currency_code
FROM AllowanceDeduction
WHERE type = 'Shift Allowance';


SELECT * FROM Currency WHERE CurrencyCode = 'USD';
EXEC EnableMultiCurrencyPayroll 
    @CurrencyCode = 'USD',
    @ExchangeRate = 31.5000;

    SELECT * FROM Currency WHERE CurrencyCode = 'USD';

    SELECT * FROM Currency WHERE CurrencyCode = 'GBP';

    EXEC EnableMultiCurrencyPayroll 
    @CurrencyCode = 'GBP',
    @ExchangeRate = 38.7500;

    SELECT * FROM Currency WHERE CurrencyCode = 'GBP';

    

    SELECT * FROM TaxForm WHERE jurisdiction = 'UAE';
    EXEC ManageTaxRules 
    @TaxRuleName = 'General Tax',
    @CountryCode = 'UAE',
    @Rate = 5,
    @Exemption = 1000;
    SELECT * FROM TaxForm WHERE jurisdiction = 'UAE';
    

    SELECT * FROM TaxForm WHERE jurisdiction = 'UAE';
    EXEC ManageTaxRules 
    @TaxRuleName = 'Revised Tax',
    @CountryCode = 'UAE',
    @Rate = 7.5,
    @Exemption = 1500;
    SELECT * FROM TaxForm WHERE jurisdiction = 'UAE';

    

    SELECT * FROM ApprovalWorkflow WHERE workflow_id = 1;

    EXEC ApprovePayrollConfigChanges
     @ConfigID = 1,
     @ApproverID = 1,
     @Status = 'Approved';

     SELECT workflow_id, status
FROM ApprovalWorkflow
WHERE workflow_id = 1;

SELECT * FROM ApprovalWorkflow WHERE workflow_id = 999;

EXEC ApprovePayrollConfigChanges
     @ConfigID = 999,
     @ApproverID = 1,
     @Status = 'Pending';

SELECT * FROM ApprovalWorkflow WHERE created_by = 1 AND status = 'Pending';

SELECT * 
FROM ApprovalWorkflow
ORDER BY workflow_id;

EXEC ApprovePayrollConfigChanges
     @ConfigID = 3,
     @ApproverID = 1,
     @Status = 'Approved';

     SELECT workflow_id, workflow_type, status
FROM ApprovalWorkflow
WHERE workflow_id = 3;



SELECT * FROM AllowanceDeduction WHERE type = 'Signing Bonus' AND employee_id = 1;

EXEC ConfigureSigningBonus
    @EmployeeID = 1,
    @BonusAmount = 2500,
    @EffectiveDate = '2024-02-10';

    SELECT payroll_id, employee_id, type, amount, currency_code
FROM AllowanceDeduction
WHERE type = 'Signing Bonus' AND employee_id = 1;

EXEC ConfigureSigningBonus
    @EmployeeID = 1,
    @BonusAmount = 3000,
    @EffectiveDate = '2023-01-01';

    SELECT payroll_id, employee_id, type, amount, currency_code
FROM AllowanceDeduction
WHERE type = 'Signing Bonus' AND employee_id = 1;



SELECT * FROM AllowanceDeduction WHERE type = 'Termination Compensation' AND employee_id = 1;

EXEC ConfigureTerminationBenefits
    @EmployeeID = 1,
    @CompensationAmount = 5000,
    @EffectiveDate = '2024-02-20',
    @Reason = 'Resignation';

    SELECT payroll_id, employee_id, type, amount, currency_code
FROM AllowanceDeduction
WHERE type = 'Termination Compensation' AND employee_id = 1;

EXEC ConfigureTerminationBenefits
    @EmployeeID = 1,
    @CompensationAmount = 4000,
    @EffectiveDate = '2023-01-15',
    @Reason = 'Old Termination Case';

     SELECT payroll_id, employee_id, type, amount, currency_code
FROM AllowanceDeduction
WHERE type = 'Termination Compensation' AND employee_id = 1;



SELECT * FROM Insurance WHERE type = 'PremiumHealth';

EXEC ConfigureInsuranceBrackets
    @InsuranceType = 'PremiumHealth',
    @MinSalary = 20000,
    @MaxSalary = 40000,
    @EmployeeContribution = 3.5,
    @EmployerContribution = 5.0;

    SELECT * FROM Insurance WHERE type = 'PremiumHealth';

    EXEC ConfigureInsuranceBrackets
    @InsuranceType = 'Medical',
    @MinSalary = 5000,
    @MaxSalary = 15000,
    @EmployeeContribution = 2,
    @EmployerContribution = 5;

    EXEC ConfigureInsuranceBrackets
    @InsuranceType = 'InvalidRange',
    @MinSalary = 50000,
    @MaxSalary = 30000,
    @EmployeeContribution = 5,
    @EmployerContribution = 5;

   

    SELECT * FROM Insurance WHERE insurance_id = 1;

    EXEC UpdateInsuranceBrackets
    @BracketID = 1,
    @MinSalary = 10000,
    @MaxSalary = 20000,
    @EmployeeContribution = 4.5,
    @EmployerContribution = 6.0;

    SELECT * FROM Insurance WHERE insurance_id = 1;

EXEC UpdateInsuranceBrackets
    @BracketID = 1,
    @MinSalary = 30000,
    @MaxSalary = 20000,
    @EmployeeContribution = 4,
    @EmployerContribution = 6;

    EXEC UpdateInsuranceBrackets
    @BracketID = 1,
    @MinSalary = 5000,
    @MaxSalary = 10000,
    @EmployeeContribution = 200,   -- invalid
    @EmployerContribution = 5;

     

     SELECT * FROM PayrollPolicy WHERE type = 'Bonus Structure' AND effective_date = '2024-05-01';

     EXEC ConfigurePayrollPolicies
    @PolicyType = 'Bonus Structure',
    @PolicyDetails = 'Standard corporate bonus rules',
    @EffectiveDate = '2024-05-01';

    SELECT * FROM PayrollPolicy WHERE type = 'Bonus Structure';

    EXEC ConfigurePayrollPolicies
    @PolicyType = 'Bonus Structure',
    @PolicyDetails = 'Duplicate Policy Attempt',
    @EffectiveDate = '2024-05-01';

    */