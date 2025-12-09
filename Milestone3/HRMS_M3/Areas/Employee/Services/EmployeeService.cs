using Dapper;
using HRMS_M3.Areas.Employee.Models;

namespace HRMS_M3.Areas.Employee.Services
{
    public class EmployeeService
    {
        private readonly DbService _db;

        public EmployeeService(DbService db)
        {
            _db = db;
        }

        // Get one employee's profile
        public async Task<EmployeeDto?> GetEmployeeByIdAsync(int id)
        {
            var result = await _db.QueryAsync<EmployeeDto>(
                "ViewEmployeeInfo",
                new { EmployeeID = id }
            );

            return result.FirstOrDefault();
        }

        // Update employee profile
        public async Task<int> UpdateEmployeeAsync(EmployeeEditViewModel vm, string? imagePath)
        {
            return await _db.ExecuteAsync(
                "UpdateEmployeeProfile",
                new
                {
                    EmployeeID = vm.Employee_Id,
                    FirstName = vm.First_Name,
                    LastName = vm.Last_Name,
                    Phone = vm.Phone,
                    Email = vm.Email,
                    Address = vm.Address,
                    EmergencyContactName = vm.Emergency_Contact_Name,
                    EmergencyContactPhone = vm.Emergency_Contact_Phone,
                    ProfileImagePath = imagePath
                }
            );
        }

        // Create a contract
        public async Task<int> CreateContractAsync(ContractViewModel vm)
        {
            return await _db.ExecuteAsync(
                "CreateContract",
                new
                {
                    EmployeeID = vm.Employee_Id,
                    ContractType = vm.Contract_Type,
                    StartDate = vm.Contract_Start,
                    EndDate = vm.Contract_End,
                    Salary = vm.Salary,
                    PayGrade = vm.Pay_Grade
                }
            );
        }

        // Get expiring contracts (e.g., next 30 days)
        public async Task<IEnumerable<dynamic>> GetExpiringContractsAsync(int days)
        {
            return await _db.QueryAsync<dynamic>(
                "GetExpiringContracts",
                new { Days = days }
            );
        }
    }
}
