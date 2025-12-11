using Dapper;
using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Services;

namespace HRMS_M3_VS.Areas.Employee.Services
{
    public class EmployeeService
    {
        private readonly DbService _db;

        public EmployeeService(DbService db)
        {
            _db = db;
        }

        // Load all employees
        public async Task<IEnumerable<EmployeeDto>> GetAllEmployeesAsync()
        {
            return await _db.QueryAsync<EmployeeDto>("GetAllEmployees", null);
        }

        // Load one employee by ID
        public async Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId)
        {
            var result = await _db.QueryAsync<EmployeeDto>(
                "ViewEmployeeInfo",
                new { EmployeeID = employeeId }
            );

            return result.FirstOrDefault();
        }

        // Update employee info
        public async Task UpdateEmployeeAsync(EmployeeEditViewModel vm)
        {
            await _db.ExecuteAsync("UpdateEmployeeInfo", new
            {
                EmployeeID = vm.Employee_Id,
                Email = vm.Email,
                Phone = vm.Phone,
                Address = vm.Address,
                EmergencyContact = vm.Emergency_Contact,
                ProfileImage = vm.ExistingImagePath
            });
        }
    }
}
