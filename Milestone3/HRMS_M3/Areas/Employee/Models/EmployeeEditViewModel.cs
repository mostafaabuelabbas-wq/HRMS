using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace HRMS_M3.Areas.Employee.Models
{
    public class EmployeeEditViewModel
    {
        public int Employee_Id { get; set; }

        [Required, StringLength(100)]
        [Display(Name = "First name")]
        public string? First_Name { get; set; }

        [Required, StringLength(100)]
        [Display(Name = "Last name")]
        public string? Last_Name { get; set; }

        [Display(Name = "Full name")]
        public string? Full_Name { get; set; }

        [Phone]
        [Display(Name = "Phone")]
        public string? Phone { get; set; }

        [EmailAddress]
        public string? Email { get; set; }

        [StringLength(250)]
        public string? Address { get; set; }

        [Display(Name = "Emergency contact name")]
        public string? Emergency_Contact_Name { get; set; }

        [Display(Name = "Emergency contact phone")]
        public string? Emergency_Contact_Phone { get; set; }

        // File upload for profile image
        [Display(Name = "Profile image")]
        public IFormFile? ProfileImageFile { get; set; }
    }
}
