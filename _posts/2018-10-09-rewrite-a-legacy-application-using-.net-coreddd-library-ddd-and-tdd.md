---
layout: post
title: Rewrite a legacy application using .NET, CoreDdd library, DDD and TDD
published: false
---
### This blog post is about rewriting a legacy ASP.NET Web Forms application using [CoreDdd](https://github.com/xhafan/coreddd/wiki) .NET library, [DDD](https://stackoverflow.com/questions/1222392/can-someone-explain-domain-driven-design-ddd-in-plain-english-please), [CQRS](https://martinfowler.com/bliki/CQRS.html) and [Chicago style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd). Comparing original legacy implementation (code-behind page model, stored procedured) with the new test driven implementation using commands, queries and domain entities.

When considering rewriting a fairly big legacy application, written in now outdated frameworks (e.g. ASP.NET Web Forms), using legacy ways of implementing a business logic (e.g. a business logic encoded in database stored procedures), which everybody is afraid to modify, there are couple of options for the application rewrite:

1. Incrementally rewrite problematic parts, adding the new code into the same application code base. Once the new implementation is ready, switch it on, and disable the old implementation. This approach enables not touching the legacy code, only adding a new code, which would not be reusing the legacy code at all. For example, when rewriting ASP.NET Web Forms app, it is possible to [add ASP.NET MVC into ASP.NET Web Forms](https://stackoverflow.com/questions/2203411/combine-asp-net-mvc-with-webforms) application, but it would not be possible to rewrite the application in ASP.NET Core MVC.
2. Incrementally rewrite problematic parts as a new application, where both applications use the same database instance. This approach allows rewriting the application in a modern framework (e.g. ASP.NET Core MVC), and running both projects in production side by side. Once the new implementation is ready, deploy it in the new application, and disable it from the legacy application. 
3. Complete application rewrite, with a new database structure, with a big bang deployment and a database migration script, with no easy way to go back when things go wrong. It takes longest time to develop, as you have to rewrite most of the features before the new application can replace the legacy one.

I personally prefer the option 2 for the following reasons:

- allows [agile software development](https://en.wikipedia.org/wiki/Agile_software_development) - a delivery of new features is frequent and regular, with a feedback from users
- the business can prioritize which features will be delivered first 
- no unrealistic fixed distant delivery deadline as with option 3

Sometimes option 1 is fine as well, as long as the framework used on the legacy project is upgradeable to a more modern (preferably latest) version (e.g. .NET 2 -> .NET 4.x). Project rewrites using options 3 I've seen mostly failed, and were destined to be slowly abandoned or rewritten yet again.

If you decide to rewrite your legacy application using [DDD](https://stackoverflow.com/questions/1222392/can-someone-explain-domain-driven-design-ddd-in-plain-english-please) because the business domain is quite complex, [CoreDdd](https://github.com/xhafan/coreddd/wiki) .NET library can help with the DDD and CQRS infrastructure for your project. It supports .NET Core 2 and higher and .NET framework 4 and higher. To learn more about CoreDdd, please refer to the CoreDdd  [documentation](https://github.com/xhafan/coreddd/wiki) and [code samples](https://github.com/xhafan/coreddd-sample).

The example legacy application we are about to rewrite will be a ship management application. This application can create new ships, update existing ships, and list existing ships. It's an ASP.NET Web Forms application, with code-behind page model, using database stored procedures to implement the server side business logic. The source code of this application is [here](https://github.com/xhafan/legacy-to-coreddd/tree/master/src/LegacyWebFormsApp). The [code to create a new ship](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/LegacyWebFormsApp/ManageShipsWebFormsAdoNet.aspx.cs#L18) might look like this:

```c#
protected void CreateShipButton_Click(object sender, EventArgs e)
{
    var shipName = CreateShipNameTextBox.Text;
    var tonnage = decimal.Parse(CreateTonnageTextBox.Text);

    _ExecuteSqlCommand(cmd =>
    {
        cmd.CommandText = $"EXEC CreateShip '{shipName}', {tonnage}";
        var shipId = (int)cmd.ExecuteScalar();
        LastShipIdCreatedLabel.Text = $"{shipId}";
    });

    Response.Redirect(Request.RawUrl);
}
```
A user fills in ship datails (ship name, tonnage, etc.), clicks *create new ship* button in the UI and the code-behind C# code will use ADO.NET to execute database stored procedure named `CreateShip`. The [stored procedure `CreateShip`](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/DatabaseScripts/ReRunnableScripts/01-StoredProcedures/0010-CreateShip.sql#L5) might look like this:

```sql
CREATE PROCEDURE CreateShip
(
    @shipName nvarchar(max)
    , @tonnage decimal(19,5)
)
AS
BEGIN

declare @shipId int

INSERT INTO Ship (
	ShipName
	, Tonnage
	)
VALUES (
	@shipName
	, @tonnage
	)
	
SELECT @shipId = SCOPE_IDENTITY()

INSERT INTO ShipHistory (
	ShipId
	, ShipName
	, Tonnage
	, CreatedOn
	)
VALUES (
    @shipId
	, @shipName
	, @tonnage
	, getdate()
	)

select @shipId

END
``` 
The sql code creates a new `Ship` table record, and a new `ShipHistory` table record, and returns generated ship id into the application.

### Incrementally rewriting a legacy application problematic parts, adding the new code into the same application code base

The 

### Incrementally rewriting a legacy application problematic parts as a new application

[implement example ASP.NET Web Forms app, executing some SP doing some crazy stuff with 2-3 tables, and show a sample rewrite over the same database using CoreDdd, DDD, **chicago TDD**] 

[Performance - publishing messages to bus] - segregation of queries and commands into their own transactions - smaller transactions, better performance;

[Chicago style controller tests - discuss advantages and disadvantages of London style vs chicago style tests - add London examples as well] 
   
[docker hub - continuous deployment]

[mention adding CI - e.g. appveyor - when multiple devs working on the project]

[add a new CoreDdd wiki page about persistence unit tests]

Steps:
1. Rewrite the project by adding code inside the project - add CoreDdd, unit tests, integration tests
2. Add a new ASP.NET Core project and re-use code added in step 1.
3. Add docker support, deploy alpine linux image of the project to docker hub
4. Run the app inside docker linux, docker pull to do an application update   