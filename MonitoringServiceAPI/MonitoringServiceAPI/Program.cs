using MonitoringServiceAPI.Data;
using MonitoringServiceAPI.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowReactApp", policy =>
    {
        policy.WithOrigins("*")
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

builder.Services.RegisterDataServices(builder.Configuration);
builder.Services.RegisterBusinessServices();


builder.Services.AddHealthChecks().AddDbContextCheck<AppDbContext>();
var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseCors("AllowReactApp");

app.MapHealthChecks("/health");

app.UseAuthorization();

app.MapControllers();

builder.Configuration.GetConnectionString("FileMonitorConnection")?.Replace("Data Source=", "").Replace("\\", "/");

app.Run();
