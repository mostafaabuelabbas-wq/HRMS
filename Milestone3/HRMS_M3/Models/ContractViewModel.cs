using System;
using System.ComponentModel.DataAnnotations;

namespace HRMS_M3.Areas.Employee.Models
{
    public class ContractViewModel
    {
        public int Employee_Id { get; set; }

        [Required]
        [Display(Name = "Contract Type")]
        public string Contract_Type { get; set; } = string.Empty;


        [Required]
        [DataType(DataType.Date)]
        [Display(Name = "Start Date")]
        public DateTime Contract_Start { get; set; }

        [Required]
        [DataType(DataType.Date)]
        [Display(Name = "End Date")]
        public DateTime Contract_End { get; set; }

        [Required]
        [Display(Name = "Salary Amount")]
        public decimal Salary { get; set; }

        [Required]
        [Display(Name = "Pay Grade")]
        public int Pay_Grade { get; set; }
    }
}
