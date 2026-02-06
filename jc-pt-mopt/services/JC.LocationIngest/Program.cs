using Dapper;
using JC.LocationIngest.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity.Data;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using System.IdentityModel.Tokens.Jwt;
using System.Net.Mime;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();

// ===============================
// Swagger + JWT (Bearer)
// ===============================
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "JC.LocationIngest", Version = "v1" });

    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Escribe: Bearer {tu_token}"
    });

    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// ===============================
// Auth (JWT)
// ===============================
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
  .AddJwtBearer(options =>
  {
      options.MapInboundClaims = false; //  mantiene "sub" como "sub"
      var jwt = builder.Configuration.GetSection("Jwt");
      options.TokenValidationParameters = new TokenValidationParameters
      {
          ValidateIssuer = true,
          ValidateAudience = true,
          ValidateLifetime = true,
          ValidateIssuerSigningKey = true,
          ValidIssuer = jwt["Issuer"],
          ValidAudience = jwt["Audience"],
          IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Key"]!)),
          ClockSkew = TimeSpan.FromSeconds(30)
      };
  });


builder.Services.AddAuthorization();

// Cloud Run + Local
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");
}

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/error", () =>
{
    return Results.Problem(
        title: "Error inesperado",
        detail: "Ocurrió un error procesando la solicitud.",
        statusCode: StatusCodes.Status500InternalServerError
    );
}).ExcludeFromDescription();

// ===============================
// Helpers generales
// ===============================
static int Clamp(int value, int min, int max) => Math.Min(Math.Max(value, min), max);

static async Task<NpgsqlConnection> OpenConnectionAsync(IConfiguration cfg)
{
    var cs = cfg.GetConnectionString("JCPostgres");
    if (string.IsNullOrWhiteSpace(cs))
        throw new InvalidOperationException("ConnectionString 'JCPostgres' no está configurada");

    var cn = new NpgsqlConnection(cs);
    await cn.OpenAsync();
    return cn;
}

// ===============================
// Password hasher (PBKDF2) - FUNCIONES LOCALES (sin clase)
// ===============================
static string GenerateSalt(int size = 16)
{
    var bytes = RandomNumberGenerator.GetBytes(size);
    return Convert.ToBase64String(bytes);
}

static string HashPassword(string password, string saltBase64, int iterations = 100_000, int keySize = 32)
{
    var salt = Convert.FromBase64String(saltBase64);
    using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256);
    var key = pbkdf2.GetBytes(keySize);
    return Convert.ToBase64String(key);
}

static bool VerifyPassword(string password, string saltBase64, string expectedHashBase64)
{
    var computed = HashPassword(password, saltBase64);
    return CryptographicOperations.FixedTimeEquals(
        Convert.FromBase64String(computed),
        Convert.FromBase64String(expectedHashBase64)
    );
}

// ===============================
// JWT helpers (FUNCIONES LOCALES)
// ===============================
static (string token, DateTime expiresAtUtc) CreateJwt(IConfiguration cfg, Guid userRecId, string userId)
{
    var jwtCfg = cfg.GetSection("Jwt");
    var issuer = jwtCfg["Issuer"]!;
    var audience = jwtCfg["Audience"]!;
    var keyStr = jwtCfg["Key"]!;
    var expiresMinutes = int.Parse(jwtCfg["ExpiresMinutes"] ?? "120");

    var now = DateTime.UtcNow;
    var expires = now.AddMinutes(expiresMinutes);

    var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr));
    var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

    var claims = new List<Claim>
    {
        new(JwtRegisteredClaimNames.Sub, userRecId.ToString()),  // sub = recid (GUID)
        new("userid", userId)
    };

    var token = new JwtSecurityToken(
        issuer: issuer,
        audience: audience,
        claims: claims,
        notBefore: now,
        expires: expires,
        signingCredentials: creds
    );

    return (new JwtSecurityTokenHandler().WriteToken(token), expires);
}

static bool TryGetUserRecId(ClaimsPrincipal user, out Guid userRecId)
{
    var sub = user.FindFirstValue(JwtRegisteredClaimNames.Sub);
    return Guid.TryParse(sub, out userRecId);
}

// ===================================
// Health
// ===================================
app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
   .WithName("Health")
   .WithOpenApi();

// ============================================================================
// AUTH
// ============================================================================

// POST /auth/login
app.MapPost("/auth/login", async (JCLoginRequest req, IConfiguration cfg) =>
{
    if (string.IsNullOrWhiteSpace(req.UserId) || string.IsNullOrWhiteSpace(req.Password))
        return Results.BadRequest(new { error = "UserId y Password son obligatorios" });

    await using var cn = await OpenConnectionAsync(cfg);

    // Tabla: jcuserinfo
    var userRow = await cn.QuerySingleOrDefaultAsync<dynamic>(@"
select
  recid,
  userid,
  email,
  passwordhash,
  passwordsalt,
  active
from jcuserinfo
where userid = @UserId
limit 1
", new { UserId = req.UserId.Trim() });

    if (userRow is null)
        return Results.Unauthorized();

    if ((bool)userRow.active == false)
        return Results.Unauthorized();

    var salt = (string?)userRow.passwordsalt;
    var hash = (string?)userRow.passwordhash;

    if (string.IsNullOrWhiteSpace(salt) || string.IsNullOrWhiteSpace(hash))
        return Results.Unauthorized();

    if (!VerifyPassword(req.Password, salt!, hash!))
        return Results.Unauthorized();

    var recId = (Guid)userRow.recid;
    var userId = (string)userRow.userid;

    // Actualizar lastlogondatetime
    await cn.ExecuteAsync(@"
update jcuserinfo
set lastlogondatetime = now(),
    modifieddatetime = now()
where recid = @RecId
", new { RecId = recId });

    var (token, expiresAtUtc) = CreateJwt(cfg, recId, userId);

    return Results.Ok(new
    {
        accessToken = token,
        expiresAtUtc
    });
})
.Accepts<JCLoginRequest>(MediaTypeNames.Application.Json)
.Produces(StatusCodes.Status200OK)
.Produces(StatusCodes.Status400BadRequest)
.Produces(StatusCodes.Status401Unauthorized)
.WithName("AuthLogin")
.WithOpenApi(op =>
{
    op.Summary = "Login y emisión de JWT";
    op.Description = "Valida UserId/Password contra jcuserinfo (PasswordHash + PasswordSalt) y retorna un JWT (sub=RecId).";
    return op;
});

// POST /auth/register  (crear usuario)
app.MapPost("/auth/register", async (JCRegisterRequest req, IConfiguration cfg) =>
{
    if (string.IsNullOrWhiteSpace(req.UserId) || string.IsNullOrWhiteSpace(req.Password))
        return Results.BadRequest(new { error = "UserId y Password son obligatorios" });

    // Reglas mínimas
    if (req.Password.Length < 8)
        return Results.BadRequest(new { error = "Password debe tener al menos 8 caracteres" });

    await using var cn = await OpenConnectionAsync(cfg);

    var exists = await cn.ExecuteScalarAsync<int>(@"
select 1 from jcuserinfo where userid = @UserId limit 1
", new { UserId = req.UserId.Trim() });

    if (exists == 1)
        return Results.Conflict(new { error = "UserId ya existe" });

    var recId = Guid.NewGuid();

    // uso de GenerateSalt()
    var salt = GenerateSalt();
    var hash = HashPassword(req.Password, salt);

    await cn.ExecuteAsync(@"
insert into jcuserinfo
(recid, userid, email, passwordhash, passwordsalt, active, lastlogondatetime, createddatetime, modifieddatetime)
values
(@RecId, @UserId, @Email, @Hash, @Salt, true, null, now(), now())
", new
    {
        RecId = recId,
        UserId = req.UserId.Trim(),
        Email = string.IsNullOrWhiteSpace(req.Email) ? null : req.Email.Trim(),
        Hash = hash,
        Salt = salt
    });

    return Results.Created($"/users/{recId}", new { id = recId, userId = req.UserId.Trim() });
})
.WithName("AuthRegister")
.WithOpenApi();


// ============================================================================
// INVENT LOCATION (Almacenes / Bodegas móviles)
// ============================================================================

// POST /inventLocations  -> Registrar almacén (y opcional ubicación)
app.MapPost("/inventLocations", async (JCInventLocationCreateRequest req, ClaimsPrincipal user, IConfiguration cfg) =>
{
    if (!TryGetUserRecId(user, out var userId))
        return Results.Unauthorized();

    if (string.IsNullOrWhiteSpace(req.InventLocationId))
        return Results.BadRequest(new { error = "InventLocationId es requerido" });

    if (string.IsNullOrWhiteSpace(req.Name))
        return Results.BadRequest(new { error = "Name es requerido" });

    await using var cn = await OpenConnectionAsync(cfg);

    var exists = await cn.ExecuteScalarAsync<int>(
        "select 1 from JCInventLocation where InventLocationId = @InventLocationId limit 1",
        new { InventLocationId = req.InventLocationId.Trim() });

    if (exists == 1)
        return Results.Conflict(new { error = "InventLocationId ya existe" });

    var recId = Guid.NewGuid();

    await cn.ExecuteAsync(@"
insert into JCInventLocation
(RecId, InventLocationId, Name, Active, IsMobile, DeviceId, Plate, DriverName,
 Latitude, Longitude, AccuracyM, LocationUpdatedAt,
 CreatedDateTime, ModifiedDateTime, CreatedByRecId, ModifiedByRecId)
values
(@RecId, @InventLocationId, @Name, @Active, @IsMobile, @DeviceId, @Plate, @DriverName,
 @Latitude, @Longitude, @AccuracyM, case when @Latitude is null or @Longitude is null then null else now() end,
 now(), now(), @UserId, @UserId)
", new
    {
        RecId = recId,
        InventLocationId = req.InventLocationId.Trim(),
        Name = req.Name.Trim(),
        Active = req.Active ?? true,
        IsMobile = req.IsMobile ?? false,
        DeviceId = string.IsNullOrWhiteSpace(req.DeviceId) ? null : req.DeviceId.Trim(),
        Plate = string.IsNullOrWhiteSpace(req.Plate) ? null : req.Plate.Trim(),
        DriverName = string.IsNullOrWhiteSpace(req.DriverName) ? null : req.DriverName.Trim(),
        Latitude = req.Latitude,
        Longitude = req.Longitude,
        AccuracyM = req.AccuracyM,
        UserId = userId
    });

    return Results.Created($"/inventLocations/{req.InventLocationId.Trim()}", new { id = recId, req.InventLocationId });
})
.RequireAuthorization()
.Accepts<JCInventLocationCreateRequest>(MediaTypeNames.Application.Json)
.Produces(StatusCodes.Status201Created)
.Produces(StatusCodes.Status400BadRequest)
.Produces(StatusCodes.Status401Unauthorized)
.Produces(StatusCodes.Status409Conflict)
.WithName("PostInventLocation")
.WithOpenApi(op =>
{
    op.Summary = "Registrar almacén (bodega fija o móvil)";
    op.Description = "Crea un registro en JCInventLocation. Si se envía lat/lon, se guarda como ubicación inicial.";
    return op;
});

// PUT /inventLocations/{inventLocationId}/location -> Actualizar ubicación (tracking)
app.MapPut("/inventLocations/{inventLocationId}/location", async (
    string inventLocationId,
    JCInventLocationUpdateLocationRequest req,
    ClaimsPrincipal user,
    IConfiguration cfg) =>
{
    if (!TryGetUserRecId(user, out var userId))
        return Results.Unauthorized();

    if (string.IsNullOrWhiteSpace(inventLocationId))
        return Results.BadRequest(new { error = "InventLocationId es requerido" });

    if (req.Latitude is null || req.Longitude is null)
        return Results.BadRequest(new { error = "Latitude y Longitude son requeridos" });

    await using var cn = await OpenConnectionAsync(cfg);

    var rows = await cn.ExecuteAsync(@"
update JCInventLocation
set
  Latitude = @Latitude,
  Longitude = @Longitude,
  AccuracyM = @AccuracyM,
  LocationUpdatedAt = now(),
  ModifiedDateTime = now(),
  ModifiedByRecId = @UserId
where InventLocationId = @InventLocationId
", new
    {
        InventLocationId = inventLocationId.Trim(),
        req.Latitude,
        req.Longitude,
        req.AccuracyM,
        UserId = userId
    });

    if (rows == 0)
        return Results.NotFound(new { error = "InventLocationId no existe" });

    return Results.Ok(new { ok = true });
})
.RequireAuthorization()
.Accepts<JCInventLocationUpdateLocationRequest>(MediaTypeNames.Application.Json)
.Produces(StatusCodes.Status200OK)
.Produces(StatusCodes.Status400BadRequest)
.Produces(StatusCodes.Status401Unauthorized)
.Produces(StatusCodes.Status404NotFound)
.WithName("PutInventLocationLocation")
.WithOpenApi(op =>
{
    op.Summary = "Actualizar ubicación de bodega móvil";
    op.Description = "Actualiza lat/lon en JCInventLocation (tracking en vivo).";
    return op;
});

// GET /inventLocations -> Listado con filtros
app.MapGet("/inventLocations", async (
    IConfiguration cfg,
    string? q,
    string? inventLocationId,
    bool? active,
    bool? isMobile,
    int page = 1,
    int pageSize = 25) =>
{
    page = Clamp(page, 1, 1_000_000);
    pageSize = Clamp(pageSize, 1, 200);

    var where = new List<string>();
    var p = new DynamicParameters();

    if (!string.IsNullOrWhiteSpace(inventLocationId))
    {
        where.Add("loc.InventLocationId = @InventLocationId");
        p.Add("InventLocationId", inventLocationId.Trim());
    }

    if (active is not null)
    {
        where.Add("loc.Active = @Active");
        p.Add("Active", active.Value);
    }

    if (isMobile is not null)
    {
        where.Add("loc.IsMobile = @IsMobile");
        p.Add("IsMobile", isMobile.Value);
    }

    if (!string.IsNullOrWhiteSpace(q))
    {
        where.Add(@"(
            loc.InventLocationId ILIKE @Q or 
            loc.Name ILIKE @Q or 
            loc.DeviceId ILIKE @Q or
            loc.Plate ILIKE @Q or
            loc.DriverName ILIKE @Q
        )");
        p.Add("Q", $"%{q.Trim()}%");
    }

    var whereSql = where.Count == 0 ? "" : "where " + string.Join(" and ", where);

    var offset = (page - 1) * pageSize;
    p.Add("Limit", pageSize);
    p.Add("Offset", offset);

    var sqlCount = $@"select count(*) from JCInventLocation loc {whereSql};";

    var sqlData = $@"
select
  loc.RecId,
  loc.InventLocationId,
  loc.Name,
  loc.Active,
  loc.IsMobile,
  loc.DeviceId,
  loc.Plate,
  loc.DriverName,
  loc.Latitude,
  loc.Longitude,
  loc.AccuracyM,
  loc.LocationUpdatedAt,
  loc.CreatedDateTime,
  loc.ModifiedDateTime
from JCInventLocation loc
{whereSql}
order by loc.InventLocationId asc
limit @Limit offset @Offset;
";

    await using var cn = await OpenConnectionAsync(cfg);

    var total = await cn.ExecuteScalarAsync<long>(sqlCount, p);
    var rows = (await cn.QueryAsync(sqlData, p)).ToList();

    return Results.Ok(new
    {
        page,
        pageSize,
        total,
        totalPages = (int)Math.Ceiling(total / (double)pageSize),
        items = rows
    });
})
.WithName("GetInventLocations")
.WithOpenApi(op =>
{
    op.Summary = "Listado de almacenes/bodegas (JCInventLocation)";
    op.Description = "Incluye bodegas móviles con lat/lon (tracking). Filtros: q, inventLocationId, active, isMobile.";
    return op;
});

// GET /inventLocations/near?lat=..&lon=..&radiusKm=10
app.MapGet("/inventLocations/near", async (
    IConfiguration cfg,
    double lat,
    double lon,
    double radiusKm = 10.0,
    bool? isMobile = null,
    int limit = 50) =>
{
    if (radiusKm <= 0 || radiusKm > 200)
        return Results.BadRequest(new { error = "radiusKm inválido (1..200)" });

    limit = Clamp(limit, 1, 200);

    var filterMobile = isMobile is null ? "" : "and loc.IsMobile = @IsMobile";

    var sql = $@"
select *
from (
  select
    loc.InventLocationId,
    loc.Name,
    loc.IsMobile,
    loc.DeviceId,
    loc.Plate,
    loc.DriverName,
    loc.Latitude,
    loc.Longitude,
    loc.AccuracyM,
    loc.LocationUpdatedAt,
    (
      6371 * 2 * asin(
        sqrt(
          power(sin(radians((@Lat - loc.Latitude) / 2)), 2) +
          cos(radians(@Lat)) * cos(radians(loc.Latitude)) *
          power(sin(radians((@Lon - loc.Longitude) / 2)), 2)
        )
      )
    ) as DistanceKm
  from JCInventLocation loc
  where loc.Latitude is not null
    and loc.Longitude is not null
    {filterMobile}
) x
where x.DistanceKm <= @RadiusKm
order by x.DistanceKm asc
limit @Limit;
";

    await using var cn = await OpenConnectionAsync(cfg);

    var rows = await cn.QueryAsync(sql, new
    {
        Lat = lat,
        Lon = lon,
        RadiusKm = radiusKm,
        IsMobile = isMobile,
        Limit = limit
    });

    return Results.Ok(rows);
})
.WithName("GetInventLocationsNear")
.WithOpenApi(op =>
{
    op.Summary = "Bodegas cercanas (radio en KM)";
    op.Description = "Devuelve bodegas con lat/lon dentro de un radio (ej. 10km). Útil para Google Maps (tipo Uber).";
    return op;
});



// ============================================================================
// PRODUCTS
// ============================================================================

// POST /products -> Crear producto
app.MapPost("/products", async (JCProductCreateRequest req, ClaimsPrincipal user, IConfiguration cfg) =>
{
    if (!TryGetUserRecId(user, out var userId))
        return Results.Unauthorized();

    if (string.IsNullOrWhiteSpace(req.ItemId))
        return Results.BadRequest(new { error = "ItemId es requerido" });

    if (string.IsNullOrWhiteSpace(req.NameAlias))
        return Results.BadRequest(new { error = "NameAlias es requerido" });

    await using var cn = await OpenConnectionAsync(cfg);

    var exists = await cn.ExecuteScalarAsync<int>(
        "select 1 from JCInventTable where ItemId = @ItemId limit 1",
        new { ItemId = req.ItemId.Trim() });

    if (exists == 1)
        return Results.Conflict(new { error = "ItemId ya existe" });

    var recId = Guid.NewGuid();

    await cn.ExecuteAsync(@"
insert into JCInventTable
(RecId, ItemId, NameAlias, Barcode, Active, CreatedDateTime, ModifiedDateTime, CreatedByRecId, ModifiedByRecId)
values
(@RecId, @ItemId, @NameAlias, @Barcode, @Active, now(), now(), @UserId, @UserId)
", new
    {
        RecId = recId,
        ItemId = req.ItemId.Trim(),
        NameAlias = req.NameAlias.Trim(),
        Barcode = string.IsNullOrWhiteSpace(req.Barcode) ? null : req.Barcode.Trim(),
        Active = req.Active ?? true,
        UserId = userId
    });

    return Results.Created($"/products/{recId}", new { id = recId, req.ItemId, req.NameAlias });
})
.RequireAuthorization()
.WithName("PostProduct")
.WithOpenApi();

// GET /products -> Paginación y filtros
app.MapGet("/products", async (
    IConfiguration cfg,
    string? q,
    string? itemId,
    string? barcode,
    bool? active,
    int page = 1,
    int pageSize = 25) =>
{
    page = Clamp(page, 1, 1_000_000);
    pageSize = Clamp(pageSize, 1, 200);

    var where = new List<string>();
    var p = new DynamicParameters();

    if (!string.IsNullOrWhiteSpace(itemId))
    {
        where.Add("it.ItemId = @ItemId");
        p.Add("ItemId", itemId.Trim());
    }

    if (!string.IsNullOrWhiteSpace(barcode))
    {
        where.Add("it.Barcode = @Barcode");
        p.Add("Barcode", barcode.Trim());
    }

    if (active is not null)
    {
        where.Add("it.Active = @Active");
        p.Add("Active", active.Value);
    }

    if (!string.IsNullOrWhiteSpace(q))
    {
        where.Add("(it.ItemId ILIKE @Q or it.NameAlias ILIKE @Q or it.Barcode ILIKE @Q)");
        p.Add("Q", $"%{q.Trim()}%");
    }

    var whereSql = where.Count == 0 ? "" : "where " + string.Join(" and ", where);

    var offset = (page - 1) * pageSize;
    p.Add("Limit", pageSize);
    p.Add("Offset", offset);

    var sqlCount = $@"select count(*) from JCInventTable it {whereSql};";

    var sqlData = $@"
select
  it.RecId,
  it.ItemId,
  it.NameAlias,
  it.Barcode,
  it.Active,
  it.CreatedDateTime,
  it.ModifiedDateTime
from JCInventTable it
{whereSql}
order by it.ItemId asc
limit @Limit offset @Offset;
";

    await using var cn = await OpenConnectionAsync(cfg);

    var total = await cn.ExecuteScalarAsync<long>(sqlCount, p);
    var rows = (await cn.QueryAsync(sqlData, p)).ToList();

    return Results.Ok(new
    {
        page,
        pageSize,
        total,
        totalPages = (int)Math.Ceiling(total / (double)pageSize),
        items = rows
    });
})
.WithName("GetProducts")
.WithOpenApi();


// ============================================================================
// INVENTORY: Stock / Transactions / Movement
// ============================================================================

// GET /inventory/stock -> Remanentes (JCInventSum)
app.MapGet("/inventory/stock", async (
    IConfiguration cfg,
    string? itemId,
    string? inventLocationId,
    decimal? minQty,
    int page = 1,
    int pageSize = 50) =>
{
    page = Clamp(page, 1, 1_000_000);
    pageSize = Clamp(pageSize, 1, 200);

    var where = new List<string>();
    var p = new DynamicParameters();

    if (!string.IsNullOrWhiteSpace(itemId))
    {
        where.Add("it.ItemId = @ItemId");
        p.Add("ItemId", itemId.Trim());
    }

    if (!string.IsNullOrWhiteSpace(inventLocationId))
    {
        where.Add("loc.InventLocationId = @InventLocationId");
        p.Add("InventLocationId", inventLocationId.Trim());
    }

    if (minQty is not null)
    {
        where.Add("s.AvailPhysical >= @MinQty");
        p.Add("MinQty", minQty.Value);
    }

    var whereSql = where.Count == 0 ? "" : "where " + string.Join(" and ", where);

    var offset = (page - 1) * pageSize;
    p.Add("Limit", pageSize);
    p.Add("Offset", offset);

    var sqlCount = $@"
select count(*)
from JCInventSum s
join JCInventTable it on it.RecId = s.InventTableRecId
join JCInventLocation loc on loc.RecId = s.InventLocationRecId
{whereSql};
";

    var sqlData = $@"
select
  it.ItemId,
  it.NameAlias,
  loc.InventLocationId,
  loc.Name as InventLocationName,
  s.AvailPhysical,
  s.RecVersion,
  s.ModifiedDateTime
from JCInventSum s
join JCInventTable it on it.RecId = s.InventTableRecId
join JCInventLocation loc on loc.RecId = s.InventLocationRecId
{whereSql}
order by it.ItemId asc, loc.InventLocationId asc
limit @Limit offset @Offset;
";

    await using var cn = await OpenConnectionAsync(cfg);

    var total = await cn.ExecuteScalarAsync<long>(sqlCount, p);
    var rows = (await cn.QueryAsync(sqlData, p)).ToList();

    return Results.Ok(new
    {
        page,
        pageSize,
        total,
        totalPages = (int)Math.Ceiling(total / (double)pageSize),
        items = rows
    });
})
.WithName("GetInventoryStock")
.WithOpenApi();

// GET /inventory/transactions -> Historial con filtros
app.MapGet("/inventory/transactions", async (
    IConfiguration cfg,
    string? itemId,
    string? inventLocationId,
    string? movementType,
    string? voucher,
    DateTimeOffset? from,
    DateTimeOffset? to,
    int page = 1,
    int pageSize = 50) =>
{
    page = Clamp(page, 1, 1_000_000);
    pageSize = Clamp(pageSize, 1, 200);

    var where = new List<string>();
    var p = new DynamicParameters();

    if (!string.IsNullOrWhiteSpace(itemId))
    {
        where.Add("it.ItemId = @ItemId");
        p.Add("ItemId", itemId.Trim());
    }

    if (!string.IsNullOrWhiteSpace(inventLocationId))
    {
        where.Add("loc.InventLocationId = @InventLocationId");
        p.Add("InventLocationId", inventLocationId.Trim());
    }

    if (!string.IsNullOrWhiteSpace(movementType))
    {
        var mt = movementType.Trim().ToUpperInvariant();
        if (mt is not ("IN" or "OUT" or "ADJUST" or "TRANSFER"))
            return Results.BadRequest(new { error = "movementType inválido (IN|OUT|ADJUST|TRANSFER)" });

        where.Add("t.TransType = @TransType::JCTransType");
        p.Add("TransType", mt);
    }

    if (!string.IsNullOrWhiteSpace(voucher))
    {
        where.Add("t.Voucher = @Voucher");
        p.Add("Voucher", voucher.Trim());
    }

    if (from is not null)
    {
        where.Add("t.CreatedDateTime >= @From");
        p.Add("From", from.Value.UtcDateTime);
    }

    if (to is not null)
    {
        where.Add("t.CreatedDateTime <= @To");
        p.Add("To", to.Value.UtcDateTime);
    }

    var whereSql = where.Count == 0 ? "" : "where " + string.Join(" and ", where);

    var offset = (page - 1) * pageSize;
    p.Add("Limit", pageSize);
    p.Add("Offset", offset);

    var sqlCount = $@"
select count(*)
from JCInventTrans t
join JCInventTable it on it.RecId = t.InventTableRecId
join JCInventLocation loc on loc.RecId = t.InventLocationRecId
{whereSql};
";

    var sqlData = $@"
select
  t.RecId as Id,
  it.ItemId,
  it.NameAlias,
  loc.InventLocationId,
  loc.Name as InventLocationName,
  t.TransType as MovementType,
  t.Qty,
  t.Reason,
  t.Voucher,
  t.CreatedByRecId as CreatedById,
  t.CreatedDateTime as CreatedAt,
  t.Latitude,
  t.Longitude,
  t.AccuracyM,
  t.DeviceTime
from JCInventTrans t
join JCInventTable it on it.RecId = t.InventTableRecId
join JCInventLocation loc on loc.RecId = t.InventLocationRecId
{whereSql}
order by t.CreatedDateTime desc
limit @Limit offset @Offset;
";

    await using var cn = await OpenConnectionAsync(cfg);

    var total = await cn.ExecuteScalarAsync<long>(sqlCount, p);
    var rows = (await cn.QueryAsync(sqlData, p)).ToList();

    return Results.Ok(new
    {
        page,
        pageSize,
        total,
        totalPages = (int)Math.Ceiling(total / (double)pageSize),
        items = rows
    });
})
.WithName("GetInventoryTransactions")
.WithOpenApi();

// GET /inventory/movement/{id}
app.MapGet("/inventory/movement/{id:guid}", async (Guid id, IConfiguration cfg) =>
{
    await using var cn = await OpenConnectionAsync(cfg);

    const string sql = @"
select
  t.RecId as Id,
  it.ItemId as ItemId,
  loc.InventLocationId as InventLocationId,
  t.TransType as MovementType,
  t.Qty as Qty,
  t.Reason as Reason,
  t.Voucher as Voucher,
  t.CreatedByRecId as CreatedById,
  t.CreatedDateTime as CreatedAt,
  t.Latitude, t.Longitude, t.AccuracyM, t.DeviceTime
from JCInventTrans t
join JCInventTable it on it.RecId = t.InventTableRecId
join JCInventLocation loc on loc.RecId = t.InventLocationRecId
where t.RecId = @Id;
";

    var row = await cn.QuerySingleOrDefaultAsync(sql, new { Id = id });
    return row is null ? Results.NotFound(new { error = "Movimiento no existe" }) : Results.Ok(row);
})
.WithName("GetInventoryMovementById")
.WithOpenApi();

// POST /inventory/movement
app.MapPost("/inventory/movement", async (JCInventoryMovementRequest req, ClaimsPrincipal user, IConfiguration cfg) =>
{
    // Usuario desde JWT (sub = recid)
    if (!TryGetUserRecId(user, out var createdById))
        return Results.Unauthorized();

    if (string.IsNullOrWhiteSpace(req.ItemId))
        return Results.BadRequest(new { error = "ItemId es requerido" });

    if (string.IsNullOrWhiteSpace(req.InventLocationId))
        return Results.BadRequest(new { error = "InventLocationId es requerido" });

    if (req.Qty <= 0)
        return Results.BadRequest(new { error = "Qty debe ser > 0" });

    var mt = (req.MovementType ?? string.Empty).Trim().ToUpperInvariant();
    if (mt is not ("IN" or "OUT" or "ADJUST" or "TRANSFER"))
        return Results.BadRequest(new { error = "MovementType inválido (IN|OUT|ADJUST|TRANSFER)" });

    await using var cn = await OpenConnectionAsync(cfg);
    await using var tx = await cn.BeginTransactionAsync();

    var inventTableRecId = await cn.ExecuteScalarAsync<Guid?>(
        "select RecId from JCInventTable where ItemId = @ItemId",
        new { ItemId = req.ItemId.Trim() },
        tx);

    var inventLocationRecId = await cn.ExecuteScalarAsync<Guid?>(
        "select RecId from JCInventLocation where InventLocationId = @InventLocationId",
        new { InventLocationId = req.InventLocationId.Trim() },
        tx);

    if (inventTableRecId is null || inventLocationRecId is null)
    {
        await tx.RollbackAsync();
        return Results.NotFound(new { error = "ItemId o InventLocationId no existe" });
    }

    // OUT: no permitir negativo
    if (mt == "OUT")
    {
        var rows = await cn.ExecuteAsync(@"
update JCInventSum s
set
  AvailPhysical     = AvailPhysical - @Qty,
  RecVersion        = RecVersion + 1,
  ModifiedDateTime  = now(),
  ModifiedByRecId   = @UserId
where s.InventTableRecId    = @ItemRecId
  and s.InventLocationRecId = @LocRecId
  and s.AvailPhysical       >= @Qty
", new
        {
            Qty = req.Qty,
            UserId = createdById,
            ItemRecId = inventTableRecId.Value,
            LocRecId = inventLocationRecId.Value
        }, tx);

        if (rows == 0)
        {
            await tx.RollbackAsync();
            return Results.Conflict(new { error = "Stock insuficiente" });
        }
    }
    else
    {
        // IN/ADJUST/TRANSFER (suma)
        await cn.ExecuteAsync(@"
insert into JCInventSum
(InventTableRecId, InventLocationRecId, AvailPhysical, RecVersion, ModifiedDateTime, ModifiedByRecId)
values
(@ItemRecId, @LocRecId, @Qty, 0, now(), @UserId)
on conflict (InventTableRecId, InventLocationRecId)
do update set
  AvailPhysical     = JCInventSum.AvailPhysical + excluded.AvailPhysical,
  RecVersion        = JCInventSum.RecVersion + 1,
  ModifiedDateTime  = now(),
  ModifiedByRecId   = @UserId
", new
        {
            Qty = req.Qty,
            UserId = createdById,
            ItemRecId = inventTableRecId.Value,
            LocRecId = inventLocationRecId.Value
        }, tx);
    }

    // Historial
    var movementId = Guid.NewGuid();

    await cn.ExecuteAsync(@"
insert into JCInventTrans
(RecId, InventTableRecId, InventLocationRecId, TransType, Qty, Reason, Voucher, CreatedByRecId, CreatedDateTime,
 Latitude, Longitude, AccuracyM, DeviceTime)
values
(@RecId, @ItemRecId, @LocRecId, @TransType::JCTransType, @Qty, @Reason, @Voucher, @UserId, now(),
 @Lat, @Lon, @Acc, @DeviceTime)
", new
    {
        RecId = movementId,
        ItemRecId = inventTableRecId.Value,
        LocRecId = inventLocationRecId.Value,
        TransType = mt,
        Qty = req.Qty,
        Reason = req.Reason,
        Voucher = req.Voucher,
        UserId = createdById,
        Lat = req.Latitude,
        Lon = req.Longitude,
        Acc = req.AccuracyM,
        DeviceTime = req.DeviceTime
    }, tx);

    await tx.CommitAsync();

    return Results.Created($"/inventory/movement/{movementId}", new { id = movementId });
})
.RequireAuthorization()
.WithName("PostInventoryMovement")
.WithOpenApi(op =>
{
    op.Summary = "Registrar movimiento de inventario";
    op.Description = "Valida stock (OUT) y registra historial en JCInventTrans. CreatedByRecId se toma del JWT (sub).";
    return op;
});



app.Run();
