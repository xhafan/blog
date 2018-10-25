---
layout: post
title: Rewrite a legacy application using .NET, CoreDdd library, DDD and TDD
published: false
---
### This blog post is about rewriting a legacy ASP.NET Web Forms application into ASP.NET Core MVC using [CoreDdd](https://github.com/xhafan/coreddd/wiki) .NET library, [DDD](https://stackoverflow.com/questions/1222392/can-someone-explain-domain-driven-design-ddd-in-plain-english-please), [CQRS](https://martinfowler.com/bliki/CQRS.html) and [Chicago style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd). Comparing original legacy implementation (code-behind page model, stored procedure) with the new test driven implementation using commands, queries and domain entities.

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

The example legacy application we are about to rewrite is a ship management application. This application can create new ships, update existing ships, and list existing ships. It's an ASP.NET Web Forms application, with code-behind page model, using database stored procedures to implement the server side business logic. The ASPX code to create a new ship might look like this:
```aspx
<form id="form1" runat="server">
    <div>
        Ship name:
        <asp:TextBox ID="ShipNameTextBox" runat="server"></asp:TextBox>
        <br />
        Tonnage:
        <asp:TextBox ID="TonnageTextBox" runat="server"></asp:TextBox>
        <br />
        <asp:Button 
            ID="CreateShipButton" 
            runat="server" 
            OnClick="CreateShipButton_Click" 
            Text="Create new ship" 
            ToolTip="Clicking the button will execute a database stored procedure to create a new ship" 
        />
        <br />
        Last ShipId created:
        <asp:Label ID="LastShipIdCreatedLabel" runat="server" Text=""></asp:Label>
    </div>
</form>
```
And the code-behind like this:
```c#
protected void CreateShipButton_Click(object sender, EventArgs e)
{
    var shipName = ShipNameTextBox.Text;
    var tonnage = decimal.Parse(TonnageTextBox.Text);

    SqlCommandExecutor.ExecuteSqlCommand(cmd =>
    {
        cmd.CommandText = $"EXEC CreateShip '{shipName}', {tonnage}";
        var shipId = (int)cmd.ExecuteScalar();
        LastShipIdCreatedLabel.Text = $"{shipId}";
    });
}

public static class SqlCommandExecutor
{
    public static void ExecuteSqlCommand(Action<SqlCommand> commandAction)
    {
        var connectionString = ConfigurationManager.ConnectionStrings["Legacy"].ConnectionString;
        using (var connection = new SqlConnection(connectionString))
        using (var cmd = connection.CreateCommand())
        {
            connection.Open();

            commandAction(cmd);
        }
    }
}
```
A user fills in ship datails (ship name, tonnage, etc.), clicks *create new ship* button in the UI and the code-behind C# code will use ADO.NET to execute database stored procedure named `CreateShip`. The stored procedure `CreateShip` might look like this (SQL Server):

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
The database tables might look like this (SQL Server):
```sql
create table Ship
(
    ShipId int IDENTITY(1,1) NOT NULL
    , ShipName nvarchar(max)
    , Tonnage decimal(19,5)
    CONSTRAINT PK_Ship_ShipId PRIMARY KEY CLUSTERED (ShipId ASC)
)

create table ShipHistory
(
    ShipHistoryId int IDENTITY(1,1) NOT NULL
    , ShipId int
    , ShipName nvarchar(max)
    , Tonnage decimal(19,5)
    , CreatedOn datetime
    CONSTRAINT PK_ShipHistory_ShipHistoryId PRIMARY KEY CLUSTERED (ShipHistoryId ASC)
)
```

The sql code creates a new `Ship` table record, and a new `ShipHistory` table record, and returns generated ship id into the application. 

The problem with this approach is that the code - both page code-behind C# and SQL - are difficult to modify because it's difficult to [unit or integration test](https://stackoverflow.com/questions/5357601/whats-the-difference-between-unit-tests-and-integration-tests) code-behind and SQL. To be able to modify a code in the long run, one has to develop the code using TDD, and with the test coverage, it's possible to modify the code in a confident way that the previous functionality won't be broken.

The motivation to rewrite an application is usually the fact that the application is not maintainable, and any change to the application causes a new set of bugs. Let's try to rewrite the code in a better maintainable way, using DDD and TDD.

### Incrementally rewriting a legacy application problematic parts, adding the new code into the same application code base

The first rewrite attempt will rewrite the ship creation code above using DDD and TDD, with the help of CoreDdd library. For this, we need to:

- add CoreDdd into the legacy ASP.NET Web Forms application. This [tutorial](https://github.com/xhafan/coreddd/wiki/ASP.NET) shows how to do it. 
- create an [aggregate root](https://stackoverflow.com/questions/1958621/whats-an-aggregate-root) domain entity `Ship` which will be mapped into `Ship` database table.
- create a domain entity `ShipHistory` which will be mapped into `ShipHistory` database table.
- create `CreateNewShipCommand` and `CreateNewShipCommandHandler` to new up the `Ship` entity and persist it into a database.
- add a new Web Forms page for the new ship creation code. The old Web Forms page will be intact, and it will be possible to compare the old and the new implementation.

Let's assume CoreDdd has been added to the legacy ASP.NET Web Forms application. As we are doing TDD, let's add `Ship` aggregate root domain entity into the legacy project, with some data properties, without any code in the constructor or methods:

```c#
public class Ship : Entity, IAggregateRoot
{
    public Ship(string name, decimal tonnage)
    {
    }

    public string Name { get; private set; }
    public decimal Tonnage { get; private set; }
}
```
A code in the constructor or any method (*behaviour* code) will be added only after we have a failing *behaviour* test, and the added *behaviour* code will make the test pass. Let's add a new class library test project for unit tests, add your favourite unit-testing framework to it (mine is [NUnit](https://www.nuget.org/packages/nunit/) and [Shouldly](https://www.nuget.org/packages/Shouldly/) as an assertion framework). Let's add a test which would test what should happen when creating a new ship, run it (you can use NUnit test runner, or [Resharper](https://www.jetbrains.com/resharper) Visual Studio extension) and see it fail:
```c#
[TestFixture]
public class when_creating_new_ship
{
    private Ship _ship;

    [SetUp]
    public void Context()
    {
        _ship = new Ship("ship name", tonnage: 23.4m);
    }

    [Test]
    public void ship_data_are_populated()
    {
        _ship.Name.ShouldBe("ship name");
        _ship.Tonnage.ShouldBe(23.4m);
    }
}
```
This test would fail as the ship name is not populated. Now that we have a failing test, we can implement the behaviour:
```c#
public class Ship : Entity, IAggregateRoot
{
    public Ship(string name, decimal tonnage)
    {
        Name = name;
        Tonnage = tonnage;
    }

    public string Name { get; private set; }
    public decimal Tonnage { get; private set; }
}
```
The test passes. Now, it should create a `ShipHistory` record when creating a new ship. Let's add a `ShipHistory` entity:
```c#
public class ShipHistory : Entity
{
    public ShipHistory(string name, decimal tonnage)
    {
    }

    public string Name { get; }
    public decimal Tonnage { get; }
    public DateTime CreatedOn { get; }
}
```
You can note here that `ShipHistory` is not marked as an aggregate root domain entity (it does not implement `IAggregateRoot` interface). `ShipHistory` entity belongs to a `Ship` entity, and `ShipHistory` existence does not make sense without `Ship` - that's why it's not an aggregate root. Let's add a collection of `ShipHistory` records into `Ship`:
```c#
    public class Ship : Entity, IAggregateRoot
    {
        private readonly ICollection<ShipHistory> _shipHistories = new List<ShipHistory>();
        ...
        public IEnumerable<ShipHistory> ShipHistories => _shipHistories;
    }
```
The private field is a collection where new `ShipHistory` records can be added, and the public property exposes the ship history collection as unmodifiable enumerable. Now we can add a new test into `when_creating_new_ship`:
```c#
[Test]
public void ship_history_record_is_created_and_its_data_are_populated()
{
    var shipHistory = _ship.ShipHistories.SingleOrDefault();
    shipHistory.ShouldNotBeNull();
    shipHistory.Name.ShouldBe("ship name");
    shipHistory.Tonnage.ShouldBe(23.4m);
    shipHistory.CreatedOn.ShouldBeInRange(DateTime.Now.AddSeconds(-10), DateTime.Now.AddSeconds(+10));
}
```
This test would fail. Now the behaviour can be implemented:
```c#
public class Ship : Entity, IAggregateRoot
{
    private readonly ICollection<ShipHistory> _shipHistories = new List<ShipHistory>();

    public Ship(string name, decimal tonnage)
    {
        ...
        _shipHistories.Add(new ShipHistory(name, tonnage));
    }
    ...
}

public class ShipHistory : Entity
{
    public ShipHistory(string name, decimal tonnage)
    {
        Name = name;
        Tonnage = tonnage;
        CreatedOn = DateTime.Now;
    }
    ...
}
``` 
The test passes. So far we unit-tested the domain entities behaviour. Let's add an integration tests for the entity mapping into database tables. Create a new class library project for integration tests, and follow this [tutorial](https://github.com/xhafan/coreddd/wiki/Persistence-tests) to add CoreDdd support for entity persistence tests. Use the NHibernate configurator created in legacy application by the previous [tutorial](https://github.com/xhafan/coreddd/wiki/ASP.NET), use the SQL scripts above to create a test database. The persistence test for `Ship` class will look like this:
```c#
[TestFixture]
public class when_persisting_ship
{
    private PersistenceTestHelper _p;
    private Ship _newShip;
    private Ship _persistedShip;

    [SetUp]
    public void Context()
    {
        _p = new PersistenceTestHelper(new MyNhibernateConfigurator()); 
        _p.BeginTransaction();

        _newShip = new Ship("ship name", tonnage: 23.4m);

        _p.Save(_newShip);
        _p.Clear();

        _persistedShip = _p.Get<Ship>(_newShip.Id);
    }

    [Test]
    public void ship_can_be_retrieved()
    {
        _persistedShip.ShouldNotBeNull();
    }

    [Test]
    public void persisted_ship_id_matches_the_saved_ship_id()
    {
        _persistedShip.ShouldBe(_newShip);
    }

    [Test]
    public void ship_data_are_persisted_correctly()
    {
        _persistedShip.Name.ShouldBe("ship name");
        _persistedShip.Tonnage.ShouldBe(23.4m);
    }

    [TearDown]
    public void TearDown()
    {
        _p.Rollback();
    }
}
``` 
When you run the persistence test, NHibernate would complain that it does not know about `Ship` entity (*NHibernate.MappingException : No persister for: Ship*). Modify the nhibernate configurator in the legacy application to map `Ship` entity:
```c#
public class MyNhibernateConfigurator : NhibernateConfigurator
{
    protected override Assembly[] GetAssembliesToMap()
    {
        return new[] { typeof(Ship).Assembly };
    }
}
```
When you run the test now, NHibernate would complain with these errors:
- *Ship: type should have a visible (public or protected) no-argument constructor*
- *Ship: method get_Name should be 'public/protected virtual' or 'protected internal virtual'* 

NHibernate can do its [ORM](https://www.tutorialspoint.com/nhibernate/nhibernate_orm.htm) magic when entities have no-argument constructors, and public/protected properties and methods are marked as virtual. Let's modify `Ship` and `ShipHistory` entities:
```c#
public class Ship : Entity, IAggregateRoot
{
	...
    protected Ship() { } // no-argument constructor

    public Ship(string name, decimal tonnage)
    {
		...
    }

    public virtual string Name { get; } // all public/protected properties marked as virtual
    public virtual decimal Tonnage { get; }
    public virtual IEnumerable<ShipHistory> ShipHistories => _shipHistories;
}
``` 
When you run the test now, NHibernate would complain about *Invalid object name 'hibernate_unique_key'*. This is because CoreDdd default entity [primary key convention](https://github.com/xhafan/coreddd/blob/master/src/CoreDdd.Nhibernate/Conventions/PrimaryKeyConvention.cs) uses [HiLo](https://stackoverflow.com/questions/282099/whats-the-hi-lo-algorithm) algorithm which  needs `hibernate_unique_key` table to generate ids for entities. But, in our example, both `Ship` and `ShipHistory` tables has ids generated by database:
```sql
create table Ship
(
    ShipId int IDENTITY(1,1) NOT NULL
    ...
)

create table ShipHistory
(
    ShipHistoryId int IDENTITY(1,1) NOT NULL
    ...
)
```
This means that the application needs to override the default CoreDdd convention by adding a customized mapping file for an entity. Add the following [FluentNHibernate](https://github.com/FluentNHibernate/fluent-nhibernate/wiki) mapping classes into the legacy application:
```c#
public class ShipMappingOverrides : IAutoMappingOverride<Ship>
{
    public void Override(AutoMapping<Ship> mapping)
    {
        mapping.Id(x => x.Id).Column("ShipId").GeneratedBy.Identity();
        mapping.Map(x => x.Name).Column("ShipName");
    }
}

public class ShipHistoryMappingOverrides : IAutoMappingOverride<ShipHistory>
{
    public void Override(AutoMapping<ShipHistory> mapping)
    {
        mapping.Id(x => x.Id).Column("ShipHistoryId").GeneratedBy.Identity();
        mapping.Map(x => x.Name).Column("ShipName");
    }
}
```
This mapping classes instruct NHibernate to map `Ship` entity `Id` property into table `Ship`, column `ShipId`, and that the id generation will be done by SQL Server identity. Also, property `Name` will be mapped into `ShipName` column.

Now the `Ship` persistence passes. Let's add a new persistence test for `ShipHistory`:
```c#
[TestFixture]
public class when_persisting_ship_history
{
    private PersistenceTestHelper _p;
    private Ship _newShip;
    private Ship _persistedShip;
    private ShipHistory _persistedShipHistory;

    [SetUp]
    public void Context()
    {
        _p = new PersistenceTestHelper(new MyNhibernateConfigurator());
        _p.BeginTransaction();

        _newShip = new Ship("ship name", tonnage: 23.4m);

        _p.Save(_newShip);

        _p.Clear();

        _persistedShip = _p.Get<Ship>(_newShip.Id);
        _persistedShipHistory = _persistedShip.ShipHistories.SingleOrDefault();
    }

    [Test]
    public void ship_history_can_be_retrieved()
    {
        _persistedShipHistory.ShouldNotBeNull();
    }

    [Test]
    public void persisted_ship_history_id_matches_the_saved_ship_history_id()
    {
        _persistedShipHistory.ShouldBe(_newShip.ShipHistories.Single());
    }

    [Test]
    public void ship_history_data_are_persisted_correctly()
    {
        _persistedShipHistory.Name.ShouldBe("ship name");
        _persistedShipHistory.Tonnage.ShouldBe(23.4m);
        _persistedShipHistory.CreatedOn.ShouldBeInRange(DateTime.Now.AddSeconds(-10), DateTime.Now.AddSeconds(+10));
    }

    [TearDown]
    public void TearDown()
    {
        _p.Rollback();
    }
}
```


As ASP.NET Web Forms is not a good fit to do TDD, we will ignore testing the code-behind page methods. 

### Incrementally rewriting a legacy ASP.NET Web Forms application problematic parts as a new ASP.NET Core MVC application

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