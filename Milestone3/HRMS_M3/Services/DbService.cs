using Microsoft.Data.SqlClient;
using Dapper;
using System.Data;

public class DbService
{
    private readonly IConfiguration _config;

    public DbService(IConfiguration config)
    {
        _config = config;
    }

    public async Task<IEnumerable<T>> QueryAsync<T>(string proc, object? parameters)
    {
        using var conn = new SqlConnection(_config.GetConnectionString("HRMS"));
        return await conn.QueryAsync<T>(proc, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<int> ExecuteAsync(string proc, object? parameters = null)
    {
        using var conn = new SqlConnection(_config.GetConnectionString("HRMS"));
        return await conn.ExecuteAsync(proc, parameters, commandType: CommandType.StoredProcedure);
    }
}
