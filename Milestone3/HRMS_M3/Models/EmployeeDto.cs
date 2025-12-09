using System;

namespace HRMS_M3.Areas.Employee.Models
{
    public class EmployeeDto
    {
        public int Employee_Id { get; set; }
        public string? First_Name { get; set; }
        public string? Last_Name { get; set; }
        public string? Full_Name { get; set; }
        public string? National_Id { get; set; }
        public DateTime? Date_Of_Birth { get; set; }
        public string? Country_Of_Birth { get; set; }
        public string? Phone { get; set; }
        public string? Email { get; set; }
        public string? Address { get; set; }
        public string? Emergency_Contact_Name { get; set; }
        public string? Emergency_Contact_Phone { get; set; }
        public string? Employment_Progress { get; set; }
        public string? Account_Status { get; set; }
        public string? Employment_Status { get; set; }
        public DateTime? Hire_Date { get; set; }
        public bool Is_Active { get; set; }
        public int Profile_Completion { get; set; }
        public int Department_Id { get; set; }
        public string? Department_Name { get; set; }
        public int Position_Id { get; set; }
        public string? Position_Title { get; set; }
        public string? Profile_Image { get; set; }
        // Add more properties if your proc returns them (use same names or alias in the proc).
    }
}
