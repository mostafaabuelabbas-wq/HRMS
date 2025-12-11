namespace HRMS_M3.Areas.Employee.Models
{
    public class AssignRoleViewModel
    {
        public int Employee_Id { get; set; }
        public string Full_Name { get; set; } = "";

        public int? CurrentRoleId { get; set; }   // nullable because some employees may not have a role yet
        public string? CurrentRoleName { get; set; }  // current role name
        public int NewRoleId { get; set; }        // selected role from dropdown

        public List<RoleDto> Roles { get; set; } = new();   // for dropdown
    }

    public class RoleDto
    {
        public int RoleId { get; set; }
        public string RoleName { get; set; } = "";
    }
}
