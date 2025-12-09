using Microsoft.AspNetCore.Mvc;

public class TestController : Controller
{
    private readonly DbService _db;

    public TestController(DbService db)
    {
        _db = db;
    }

    public async Task<IActionResult> CallProc()
    {
        var result = await _db.QueryAsync<dynamic>(
            "dbo.ViewEmployeeInfo",
            new { EmployeeID = 1 }
        );

        return Json(result);
    }
}
