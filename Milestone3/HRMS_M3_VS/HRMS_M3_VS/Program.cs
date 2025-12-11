using Microsoft.Data.SqlClient;
var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();
// TEST DATABASE CONNECTION (temporary)
try
{
    using var conn = new Microsoft.Data.SqlClient.SqlConnection(builder.Configuration.GetConnectionString("HRMS"));
    conn.Open();
    Console.WriteLine("DATABASE CONNECTION SUCCESSFUL ✔");
}
catch (Exception ex)
{
    Console.WriteLine("DATABASE CONNECTION FAILED ❌");
    Console.WriteLine(ex.Message);
}

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();
// ADD THIS AREA ROUTE FIRST
app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
