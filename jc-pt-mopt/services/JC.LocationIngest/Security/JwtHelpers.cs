using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace JC.LocationIngest.Security;

public static class JwtHelpers
{
    public static (string token, DateTime expiresAtUtc) CreateJwt(IConfiguration cfg, Guid userRecId, string userId)
    {
        var jwtCfg = cfg.GetSection("Jwt");
        var issuer = jwtCfg["Issuer"];
        var audience = jwtCfg["Audience"];
        var keyStr = jwtCfg["Key"];
        var expiresMinutes = int.Parse(jwtCfg["ExpiresMinutes"] ?? "120");

        var now = DateTime.UtcNow;
        var expires = now.AddMinutes(expiresMinutes);

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userRecId.ToString()),
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
}
