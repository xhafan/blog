---
layout: post
title: Rewrite a legacy application using .NET, CoreDdd library, DDD and TDD
published: false
---
Posted By [Martin Havlišta](https://xhafan.com/blog/about.html)

### About rewriting a legacy ASP.NET Web Forms application into ASP.NET Core MVC using [CoreDdd](https://github.com/xhafan/coreddd/wiki) .NET library, [DDD](https://stackoverflow.com/questions/1222392/can-someone-explain-domain-driven-design-ddd-in-plain-english-please), [CQRS](https://martinfowler.com/bliki/CQRS.html) and [Chicago style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd). Comparing original legacy implementation (code-behind page model, stored procedure) with the new test driven implementation using commands, queries and domain entities.

### Table of Contents
- [Options for rewrite](#options_for_rewrite)
- [Example legacy application](#example_legacy_app)
- [Incrementally rewriting a legacy application problematic parts, adding the new code into the same application code base](#rewrite_in_existing_app)
- [Incrementally rewriting a legacy application problematic parts as a new ASP.NET Core MVC application](#rewrite_as_new_app)
- [Performance boost](#performance_boost)
- [Reliable command handling](#reliable_command_handling)

### <a name="options_for_rewrite"></a>Options for rewrite

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

### <a name="example_legacy_app"></a>Example legacy application

The example legacy application we are about to rewrite is a ship management application. This application can create new ships, update existing ships, and list existing ships. It's an ASP.NET Web Forms, .NET 4 application, with code-behind page model, using database stored procedures to implement the server side business logic. The ASPX code to create a new ship might look like this:
```aspx
<form id="form1" runat="server">
    <div>
        Ship name:
        <asp:TextBox ID="ShipNameTextBox" runat="server"></asp:TextBox>
        <br />
        Tonnage:
        <asp:TextBox ID="TonnageTextBox" runat="server"></asp:TextBox>
        <br />
        IMO (International Maritime Organization) Number:
        <asp:TextBox ID="ImoNumberTextBox" runat="server"></asp:TextBox>
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
    var imoNumber = ImoNumberTextBox.Text;

    SqlCommandExecutor.ExecuteSqlCommand(cmd =>
    {
        const int hasImoNumberBeenVerified = 1;
        cmd.CommandText = 
            $"EXEC CreateShip '{shipName}', {tonnage}, '{imoNumber}'";
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
A user fills in ship datails (ship name, tonnage, IMO number etc.), clicks *create new ship* button in the UI and the code-behind C# code will use ADO.NET to execute database stored procedure named `CreateShip`. The stored procedure `CreateShip` might look like this (SQL Server):

```sql
CREATE PROCEDURE CreateShip
(
    @shipName nvarchar(max)
    , @tonnage decimal(19,5)
    , @imoNumber nvarchar(max)
)
AS
BEGIN

declare @shipId int

INSERT INTO Ship (
    ShipName
    , Tonnage
    , ImoNumber
    )
VALUES (
    @shipName
    , @tonnage
    , @imoNumber
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
    , ImoNumber nvarchar(max)
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
The sql code creates a new `Ship` table record, and a new `ShipHistory` table record, and returns created ship id into the application.

The source code of this application is [here](https://github.com/xhafan/legacy-to-coreddd/tree/master/src/LegacyWebFormsApp), SQL scripts [here](https://github.com/xhafan/legacy-to-coreddd/tree/master/src/DatabaseScripts). To open the solution, you will need [Visual Studio 2017](https://visualstudio.microsoft.com/downloads/) or higher and [.NET Core 2.1](https://www.microsoft.com/net/download) or higher. The solution uses a SQL Server LocalDB database. Here's how to [install SQL Server LocalDB](https://stackoverflow.com/questions/42774739/how-to-install-localdb-2016-along-with-visual-studio-2017). You need to manually create two databases `Legacy` and `LegacyTest`, the application will automatically build the database using SQL scripts using [DatabaseBuilder](https://github.com/xhafan/databasebuilder/wiki). 

One of the problems with Web Forms code-behind and business logic inside SQL stored procedures is that the code - both page code-behind C# and SQL - are difficult to modify because it's difficult to [unit or integration test](https://stackoverflow.com/questions/5357601/whats-the-difference-between-unit-tests-and-integration-tests) code-behind and SQL. To be able to modify a code in the long run, one has to develop the code using TDD, and with the test coverage, it's possible to modify the code in a confident way that the previous functionality won't be broken.

The motivation to rewrite an application is usually the fact that the application is not maintainable, and any change to the application causes a new set of bugs. Let's try to rewrite the code in a better maintainable way, using DDD and TDD.

### <a name="rewrite_in_existing_app"></a>Incrementally rewriting a legacy application problematic parts, adding the new code into the same application code base

The first rewrite attempt will rewrite the ship creation code above using DDD and TDD, with the help of CoreDdd library. For this, we need to:

- create an [aggregate root](https://stackoverflow.com/questions/1958621/whats-an-aggregate-root) domain entity `Ship` which will be mapped into `Ship` database table.
- create a domain entity `ShipHistory` which will be mapped into `ShipHistory` database table.
- create `CreateNewShipCommand` and `CreateNewShipCommandHandler` to new up the `Ship` entity and persist it into a database.
- add a new Web Forms page for the new ship creation code. The old Web Forms page will be intact, and it will be possible to compare the old and the new implementation.
 
Let's implement the domain and command/command handler code in a new .NET Standard class library. We will manually multi-target .NET 4 and .NET Standard 2.0, so we can reuse the implementation within the existing legacy .NET 4 Web Forms application, and later in the ASP.NET Core MVC application. Manually edit the csproj file, and change the `TargetFramework` line to (please note the **s** in `TargetFrameworks`): 
```xml
<TargetFrameworks>netstandard2.0;net40</TargetFrameworks>
```  
Add CoreDdd into the legacy ASP.NET Web Forms application by following this [tutorial](https://github.com/xhafan/coreddd/wiki/ASP.NET). Once done, move the NHiberate configurator class into the newly created class library.

As we are doing TDD, let's add `Ship` aggregate root domain entity into the newly created library, with some data properties, without any code in the constructor or methods:

```c#
public class Ship : Entity, IAggregateRoot
{
    public Ship(string name, decimal tonnage)
    {
    }

    public string Name { get; private set; }
    public decimal Tonnage { get; private set; }
    public string ImoNumber { get; protected set; }
}
```
A code in the constructor or any method (*behaviour* code) will be added only after we have a failing *behaviour* test, and the added *behaviour* code will make the test pass. Let's add a new .NET Core class library test project for unit tests, manually multi-target .NET 4 and .NET Core 2.1 in csproj file (`<TargetFrameworks>net40;netcoreapp2.1</TargetFrameworks>`) and add your favourite unit-testing framework to it (mine is [NUnit](https://www.nuget.org/packages/nunit/) and [Shouldly](https://www.nuget.org/packages/Shouldly/) as an assertion framework). Let's add a test which would test what should happen when creating a new ship, run it (you can use NUnit test runner, or [Resharper](https://www.jetbrains.com/resharper) Visual Studio extension) and see it fail:
```c#
[TestFixture]
public class when_creating_new_ship
{
    private Ship _ship;

    [SetUp]
    public void Context()
    {
        _ship = new Ship("ship name", tonnage: 23.4m, imoNumber: "IMO 12345");
    }

    [Test]
    public void ship_data_are_populated()
    {
        _ship.Name.ShouldBe("ship name");
        _ship.Tonnage.ShouldBe(23.4m);
        _ship.ImoNumber.ShouldBe("IMO 12345");
    }
}
```
This test would fail as the ship name is not populated. Now that we have a failing test, we can implement the behaviour:
```c#
public class Ship : Entity, IAggregateRoot
{
    public Ship(string name, decimal tonnage, string imoNumber)
    {
        Name = name;
        Tonnage = tonnage;
        ImoNumber = imoNumber;
    }

    public string Name { get; private set; }
    public decimal Tonnage { get; private set; }
    public string ImoNumber { get; private set; }
}
```
The test passes. Now, it should create a `ShipHistory` record when creating a new ship. Let's add a `ShipHistory` entity:
```c#
public class ShipHistory : Entity
{
    public ShipHistory(string name, decimal tonnage)
    {
    }

    public string Name { get; private set; }
    public decimal Tonnage { get; private set; }
    public DateTime CreatedOn { get; private set; }
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

    public Ship(string name, decimal tonnage, string imoNumber)
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
The test passes. So far we unit-tested the domain entities behaviour. Let's add an integration tests for the entity mapping into database tables. Create a new .NET Core class library project for integration tests, manually multi-target .NET 4 and .NET Core 2.1 in csproj file (`<TargetFrameworks>net40;netcoreapp2.1</TargetFrameworks>`) and follow this [tutorial](https://github.com/xhafan/coreddd/wiki/Persistence-tests) to add CoreDdd support for entity persistence tests. Use the NHibernate configurator created in the steps above and use the SQL scripts above to create a test database. The persistence test for `Ship` class will look like this:
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
        _p = new PersistenceTestHelper(new CoreDddSharedNhibernateConfigurator()); 
        _p.BeginTransaction();

        _newShip = new Ship("ship name", tonnage: 23.4m, imoNumber: "IMO 12345");

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
        _persistedShip.ImoNumber.ShouldBe("IMO 12345");
    }

    [TearDown]
    public void TearDown()
    {
        _p.Rollback();
    }
}
``` 
When you run the persistence test, NHibernate would complain that it does not know about `Ship` entity (*NHibernate.MappingException : No persister for: Ship*). Modify the NHibernate configurator to map `Ship` entity:
```c#
public class CoreDddSharedNhibernateConfigurator : NhibernateConfigurator
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
- *Ship: method set_Name should be 'public/protected virtual' or 'protected internal virtual'*

NHibernate can do its [ORM](https://www.tutorialspoint.com/nhibernate/nhibernate_orm.htm) magic when entities have no-argument constructors, and public/protected properties and methods are marked as virtual. Let's modify `Ship` and `ShipHistory` entities:
```c#
public class Ship : Entity, IAggregateRoot
{
    ...
    protected Ship() { } // no-argument constructor

    public Ship(string name, decimal tonnage, string imoNumber)
    {
        ...
    }

    public virtual string Name { get; protected set; } // all public/protected properties and methods marked as virtual
    public virtual decimal Tonnage { get; protected set; } // all setters are protected
    public virtual string ImoNumber { get; protected set; }
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
This mapping classes instruct NHibernate to map `Ship` entity `Id` property into table `Ship`, column `ShipId`, and that the id generation will be done by SQL Server identity. Also, property `Name` will be mapped into `ShipName` column. Similar mapping for `ShipHistory`.

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

        _newShip = new Ship("ship name", tonnage: 23.4m, imoNumber: "IMO 12345");

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
These tests should pass straight away. The domain code covered by unit tests and integration tests is complete. Now we need to add a command `CreateNewShipCommand` implementing `ICommand` marker interface:
```c#
public class CreateNewShipCommand : ICommand
{
    public string ShipName { get; set; }
    public decimal Tonnage { get; set; }
    public string ImoNumber { get; set; }
}
```
And a command handler `CreateNewShipCommandHandler` without any implementation:
```c#
public class CreateNewShipCommandHandler : BaseCommandHandler<CreateNewShipCommand>
{
    public CreateNewShipCommandHandler(IRepository<Ship> shipRepository)
    {
    }

    public override void Execute(CreateNewShipCommand command)
    {
    }
}
```
Command handler has a ship repository passed into a constructor as it will be needed to save the new ship into a database. It's derived from [`BaseCommandHandler`](https://github.com/xhafan/coreddd/blob/master/src/CoreDdd/Commands/BaseCommandHandler.cs), but instead of inheritance you could just implement [`ICommandHandler`](https://github.com/xhafan/coreddd/blob/master/src/CoreDdd/Commands/ICommandHandler.cs) (`BaseCommandHandler` adds some helper code for convenience). Following the TDD, let's add a command handler test first:
```c#
[TestFixture]
public class when_creating_new_ship
{
    private PersistenceTestHelper _p;
    private Ship _persistedShip;
    private int _createdShipId;

    [SetUp]
    public void Context()
    {
        _p = new PersistenceTestHelper(new MyNhibernateConfigurator());
        _p.BeginTransaction();

        var createNewShipCommand = new CreateNewShipCommand
        {
            ShipName = "ship name",
            Tonnage = 23.45678m,
            ImoNumber = "IMO 765432"
        };
        var createNewShipCommandHandler = new CreateNewShipCommandHandler(new NhibernateRepository<Ship>(_p.UnitOfWork));
        createNewShipCommandHandler.CommandExecuted += args => _createdShipId = (int) args.Args;
        createNewShipCommandHandler.Execute(createNewShipCommand);

        _p.Clear();

        _persistedShip = _p.Get<Ship>(_createdShipId);
    }

    [Test]
    public void ship_can_be_retrieved_and_data_are_persisted_correctly()
    {
        _persistedShip.ShouldNotBeNull();
        _persistedShip.Name.ShouldBe("ship name");
        _persistedShip.Tonnage.ShouldBe(23.45678m);
        _persistedShip.ImoNumber.ShouldBe("IMO 765432");
    }

    [TearDown]
    public void TearDown()
    {
        _p.Rollback();
    }
}
```
This test fails. Let's implement the command handler:
```c#
public class CreateNewShipCommandHandler : BaseCommandHandler<CreateNewShipCommand>
{
    private readonly IRepository<Ship> _shipRepository;

    public CreateNewShipCommandHandler(IRepository<Ship> shipRepository)
    {
        _shipRepository = shipRepository;
    }

    public override void Execute(CreateNewShipCommand command)
    {
        var newShip = new Ship(command.ShipName, command.Tonnage, command.ImoNumber);
        _shipRepository.Save(newShip);

        RaiseCommandExecutedEvent(new CommandExecutedArgs { Args = newShip.Id });
    }
}
```
The test passes. Please note that the command handler test should test just the command handler and the happy path of the domain code, any branching (=if) in the domain entity code should be covered by a domain tests and not command handler tests. Also, this test is [Chicago style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd) test, which adds value of knowing that things work end to end. Let's see how [London style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd) unit test would look like (with the help of mocking library [FakeItEasy](https://www.nuget.org/packages/FakeItEasy)):
```c#
using FakeItEasy;

[TestFixture]
public class when_creating_new_ship
{
    private int _createdShipId;
    private IRepository<Ship> _shipRepository;

    [SetUp]
    public void Context()
    {
        var createNewShipCommand = new CreateNewShipCommand
        {
            ShipName = "ship name",
            Tonnage = 23.45678m,
            ImoNumber = "IMO 12345"
        };
        _shipRepository = A.Fake<IRepository<Ship>>();
        A.CallTo(() => _shipRepository.Save(A<Ship>._)).Invokes(x =>
        {
            // when shipRepository.Save() is called, simulate NHibernate assigning Id to the Ship entity
            var shipPassedAsParameter = x.GetArgument<Ship>(0);
            shipPassedAsParameter.SetPrivateProperty("Id", 23);
        });
        var createNewShipCommandHandler = new CreateNewShipCommandHandler(_shipRepository);
        createNewShipCommandHandler.CommandExecuted += args => _createdShipId = (int) args.Args;
        createNewShipCommandHandler.Execute(createNewShipCommand);
    }

    [Test]
    public void ship_is_saved_with_correct_data()
    {
        A.CallTo(() => _shipRepository.Save(A<Ship>.That.Matches(p => _MatchingShip(p)))).MustHaveHappened();
    }

    private bool _MatchingShip(Ship p)
    {
        p.Name.ShouldBe("ship name");
        p.Tonnage.ShouldBe(23.45678m);
        p.ImoNumber.ShouldBe("IMO 12345");
        return true;
    }

    [Test]
    public void command_executed_event_is_raised_with_stubbed_ship_id()
    {
        _createdShipId.ShouldBe(23);
    }
}
public static class ObjectExtensions
{
    public static void SetPrivateProperty(this object obj, string propertyName, object value)
    {
        obj.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public).SetValue(obj, value, null);
    }
}
```
This London style TDD unit test for `CreateNewShipCommandHandler` does not add much value. Yes, it is faster to execute (as it's not dealing with a database), but there no point in [stubbing or mocking](https://stackoverflow.com/questions/346372/whats-the-difference-between-faking-mocking-and-stubbing) things when one can just use real objects and test it end to end. I would even say that unit-testing adds value when you don't have to stub or mock. When you have to stub or mock a lot for the sake of having a unit test, I would suggest try Chicago style TDD unit test with real objects, or, if database is needed, try an integration test, and see for yourself which test adds more value for you.

The next thing is to call the command handler from the Web Forms page code-behind:
```c#
public partial class CreateShip : Page
{
    private ICommandExecutor _commandExecutor;

    protected void Page_Load(object sender, EventArgs e)
    {
        _commandExecutor = IoC.Resolve<ICommandExecutor>();
    }

    protected void CreateShipButton_Click(object sender, EventArgs e)
    {
        var createNewShipCommand = new CreateNewShipCommand
        {
            ShipName = ShipNameTextBox.Text,
            Tonnage = decimal.Parse(TonnageTextBox.Text),
            ImoNumber = ImoNumberTextBox.Text
        };

        _commandExecutor.CommandExecuted += args =>
        {
            var createdShipId = (int)args.Args;
            LastShipIdCreatedLabel.Text = $"{createdShipId}";
        };
        _commandExecutor.Execute(createNewShipCommand);
    }

    protected void Page_Unload(object sender, EventArgs e)
    {
        IoC.Release(_commandExecutor);
    }
}
```
For an explanation why the code uses Service Locator pattern (`IoC.Resolve<>()`), please have look at this [tutorial](https://github.com/xhafan/coreddd/wiki/ASP.NET).

As the ASP.NET Web Forms page code-behind is not a good fit to do TDD, we will ignore testing it. The source code of the new create ship implementation using DDD and CQRQ is available [here](https://github.com/xhafan/legacy-to-coreddd/tree/master/src/LegacyWebFormsApp/WebFormsCoreDdd). You can find there other two Web Form pages to update a ship, and to list existing ships. You can compare the new implementation to the [legacy one](https://github.com/xhafan/legacy-to-coreddd/tree/master/src/LegacyWebFormsApp/WebFormsAdoNet).

### <a name="rewrite_as_new_app"></a>Incrementally rewriting a legacy application problematic parts as a new ASP.NET Core MVC application

Create a new ASP.NET Core MVC application, and follow this [tutorial](https://github.com/xhafan/coreddd/wiki/ASP.NET-Core) to add CoreDdd into it. Don't create a new NHibernate configurator class, but reference the one from the shared library created for the Web Forms application (see above). The application will also partially reuse the domain code and the create new ship command/command handler.

Create a new controller `ManageShipsController` with an empty method `CreateNewShip`:
```c#
public class ManageShipsController : Controller
{
    public ManageShipsController(ICommandExecutor commandExecutor)
    {
    }

    [HttpPost]
    public async Task<IActionResult> CreateNewShip(CreateNewShipCommand createNewShipCommand)
    {
        return null;
    }
}
```
We will add a Chicago style TDD integration test for the controller `CreateNewShip` method, and later a London style TDD unit test as well so we can compare the two. Create a new .NET Core class library, add your favourite unit testing framework to it (for [NUnit](https://nunit.org/) and .NET Core, please follow this [article](https://github.com/nunit/docs/wiki/.NET-Core-and-.NET-Standard)), follow this [tutorial](https://github.com/xhafan/coreddd/wiki/Persistence-tests) to add CoreDdd support for entity persistence tests, and add the [Microsoft.AspNetCore.Mvc](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc/) nuget package into it. Add *create new ship* test: 
```c#
[TestFixture]
public class when_creating_new_ship
{
    private PersistenceTestHelper _p;
    private ServiceProvider _serviceProvider;
    private IServiceScope _serviceScope;

    private IActionResult _actionResult;
    private int _shipCountBefore;

    [SetUp]
    public async Task Context()
    {
        _serviceProvider = new ServiceProviderHelper().BuildServiceProvider();
        _serviceScope = _serviceProvider.CreateScope();

        _p = new PersistenceTestHelper(_serviceProvider.GetService<NhibernateUnitOfWork>());
        _p.BeginTransaction();

        _shipCountBefore = _GetShipCount();

        var manageShipsController = new ManageShipsControllerBuilder(_serviceProvider).Build();

        var createNewShipCommand = new CreateNewShipCommand
        {
            ShipName = "ship name",
            Tonnage = 23.4m,
            ImoNumber = "IMO 12345"
        };
        _actionResult = await manageShipsController.CreateNewShip(createNewShipCommand);

        _p.Flush();
        _p.Clear();
    }

    [Test]
    public void new_ship_is_created()
    {
        _GetShipCount().ShouldBe(_shipCountBefore + 1);
    }

    [Test]
    public void action_result_is_redirect_to_action_result()
    {
        _actionResult.ShouldBeOfType<RedirectToActionResult>();
        var redirectToActionResult = (RedirectToActionResult)_actionResult;
        redirectToActionResult.ControllerName.ShouldBeNull();
        redirectToActionResult.ActionName.ShouldBe("CreateNewShip");
    }

    [TearDown]
    public void TearDown()
    {
        _p.Rollback();
        _serviceScope.Dispose();
        _serviceProvider.Dispose();
    }

    private int _GetShipCount()
    {
        return _p.UnitOfWork.Session.QueryOver<Ship>().RowCount();
    }
}

public class ServiceProviderHelper
{
    public ServiceProvider BuildServiceProvider()
    {
        var services = new ServiceCollection();
        services.AddCoreDdd();
        services.AddCoreDddNhibernate<CoreDddSharedNhibernateConfigurator>();

        // register command handlers
        services.Scan(scan => scan
            .FromAssemblyOf<Ship>()
            .AddClasses(classes => classes.AssignableTo(typeof(ICommandHandler<>)))
            .AsImplementedInterfaces()
            .WithTransientLifetime()
        );
        return services.BuildServiceProvider();
    }
}

public class ManageShipsControllerBuilder
{
    private readonly ServiceProvider _serviceProvider;

    public ManageShipsControllerBuilder(ServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public ManageShipsController Build()
    {
        var commandExecutor = new CommandExecutor(_serviceProvider.GetService<ICommandHandlerFactory>());
        return new ManageShipsController(commandExecutor);
    }
}
```
The integration test checks that after the controller `CreateNewShip` method call there is a new ship created in the database. The test fails. Let's implement the controller method `CreateNewShip`:
```c#
public class ManageShipsController : Controller
{
    private readonly ICommandExecutor _commandExecutor;

    public ManageShipsController(ICommandExecutor commandExecutor)
    {
        _commandExecutor = commandExecutor;
    }

    [HttpPost]
    public async Task<IActionResult> CreateNewShip(CreateNewShipCommand createNewShipCommand)
    {
        await _commandExecutor.ExecuteAsync(createNewShipCommand);

        return RedirectToAction("CreateNewShip");
    }
}
``` 
The test passes. Let's implement controller method to view `CreateNewShip` view:
```c#
public class ManageShipsController : Controller
{
    ...
    public IActionResult CreateNewShip()
    {
        return null;
    }
    ...
}
``` 
Let's add the integration test first:
```c#
[TestFixture]
public class when_viewing_create_new_ship
{
    private PersistenceTestHelper _p;
    private ServiceProvider _serviceProvider;
    private IServiceScope _serviceScope;

    private IActionResult _actionResult;

    [SetUp]
    public void Context()
    {
        _serviceProvider = new ServiceProviderHelper().BuildServiceProvider();
        _serviceScope = _serviceProvider.CreateScope();

        _p = new PersistenceTestHelper(_serviceProvider.GetService<NhibernateUnitOfWork>());
        _p.BeginTransaction();

        var manageShipsController = new ManageShipsControllerBuilder(_serviceProvider).Build();

        _actionResult = manageShipsController.CreateNewShip();
    }

    [Test]
    public void action_result_is_view_result()
    {
        _actionResult.ShouldBeOfType<ViewResult>();
    }

    [TearDown]
    public void TearDown()
    {
        _p.Rollback();
        _serviceScope.Dispose();
        _serviceProvider.Dispose();
    }
}
```
The test fails. Let's implement the controller method:
```c#
public IActionResult CreateNewShip()
{
    return View();
}
```
The test passes. You might wonder why adding this complex test for a method returning just a view. Well, first, the test is complex because lot of stuff need to happen first before the controller action method can be executed. Second, the test complexity could be extracted into a test base class, and shared between `ManageShipsController` tests, so the test would not be that complex. And third, another developer might add some behaviour in the future, so it's handy to have the test ready.  
 
Now, let's add the view:
```xml
@model CoreDddShared.Commands.CreateNewShipCommand
@{
    ViewData["Title"] = "Create new ship";
}

<form method="post">
    Ship Name:
    <input asp-for="ShipName" />
    <br />
    Tonnage:
    <input asp-for="Tonnage" />
    <br />
    IMO (International Maritime Organization) number:
    <input asp-for="ImoNumber" />
    <br />
    <button type="submit" title="Clicking the button will execute a command to create a new ship">Create new ship</button>
</form>
``` 
Now you can run the application, navigate to the *create new ship* view, and it should be possible to create a new ship. Let's slightly improve the *create new ship* view to show the last ship id created. We need to modify the existing test:
```c#
[Test]
public void action_result_is_redirect_to_action_result_with_last_created_ship_id_parameterer()
{
    _actionResult.ShouldBeOfType<RedirectToActionResult>();
    var redirectToActionResult = (RedirectToActionResult) _actionResult;
    redirectToActionResult.ControllerName.ShouldBeNull();
    redirectToActionResult.ActionName.ShouldBe("CreateNewShip");
    redirectToActionResult.RouteValues.ShouldNotBeNull();
    redirectToActionResult.RouteValues.ContainsKey("lastCreatedShipId").ShouldBeTrue();
    ((int)redirectToActionResult.RouteValues["lastCreatedShipId"]).ShouldBeGreaterThan(0);
}
```
The test fails. Let's modify the controller method:
```c#
[HttpPost]
public async Task<IActionResult> CreateNewShip(CreateNewShipCommand createNewShipCommand)
{
    var createdShipId = 0;
    _commandExecutor.CommandExecuted += args => createdShipId = (int)args.Args;
    await _commandExecutor.ExecuteAsync(createNewShipCommand);

    return RedirectToAction("CreateNewShip", new { lastCreatedShipId = createdShipId });
}
```
The test passes. We need to modify the view to show the last created ship id:
```xml
    ...    
    <button type="submit" title="Clicking the button will execute a command to create a new ship">Create new ship</button>
    <br />
    Last ShipId created: @Context.Request.Query["lastCreatedShipId"]
</form>
```
Let's see how the London style TDD unit test for the `CreateNewShip` controller method would look like so we can compare it with the Chicago style TDD:
```c#
using FakeItEasy;
...
[TestFixture]
public class when_creating_new_ship
{
    private IActionResult _actionResult;
    private ICommandExecutor _commandExecutor;
    private CreateNewShipCommand _createNewShipCommand;
    private const int CreatedShipId = 34;

    [SetUp]
    public async Task Context()
    {
        _createNewShipCommand = new CreateNewShipCommand
        {
            ShipName = "ship name",
            Tonnage = 23.4m,
            ImoNumber = "IMO 12345"
        };

        _commandExecutor = A.Fake<ICommandExecutor>();
        _FakeThatWhenCommandIsExecutedTheCommandExecutedEventIsRaisedWithCreatedShipIdAsEventArgs();
        var queryExecutor = A.Fake<IQueryExecutor>();
        var manageShipsController = new ManageShipsController(_commandExecutor, queryExecutor);

        _actionResult = await manageShipsController.CreateNewShip(_createNewShipCommand);
    }

    [Test]
    public void command_is_executed()
    {
        A.CallTo(() => _commandExecutor.ExecuteAsync(_createNewShipCommand)).MustHaveHappened();
    }

    [Test]
    public void action_result_is_redirect_to_action_result_with_last_created_ship_id_parameterer()
    {
        _actionResult.ShouldBeOfType<RedirectToActionResult>();
        var redirectToActionResult = (RedirectToActionResult)_actionResult;
        redirectToActionResult.ControllerName.ShouldBeNull();
        redirectToActionResult.ActionName.ShouldBe("CreateNewShip");
        redirectToActionResult.RouteValues.ShouldNotBeNull();
        redirectToActionResult.RouteValues.ContainsKey("lastCreatedShipId").ShouldBeTrue();
        ((int)redirectToActionResult.RouteValues["lastCreatedShipId"]).ShouldBe(CreatedShipId);
    }

    // This method is simulating "what would happen in real command executor"
    private void _FakeThatWhenCommandIsExecutedTheCommandExecutedEventIsRaisedWithCreatedShipIdAsEventArgs()
    {
        A.CallTo(() => _commandExecutor.ExecuteAsync(_createNewShipCommand)).Invokes(() =>
        {
            _commandExecutor.CommandExecuted +=
                Raise.FreeForm<Action<CommandExecutedArgs>>.With(new CommandExecutedArgs { Args = CreatedShipId });
        });
    }
}
```  
This London style TDD unit test needs to do some hacky stuff about simulating command executor behaviour to make it work. In my opinion, it is a useless test adding no value as one needs to simulate expected behaviour of other components.

The source code of the new ASP.NET Core MVC create ship implementation using DDD and CQRS is available [here](https://github.com/xhafan/legacy-to-coreddd/tree/master/src/AspNetCoreMvcApp). In there you can find an implementation of a ship update view, and listing existing ships view.

### <a name="performance_boost"></a>Performance boost
If your application is doing too much when handling a request, and some of the processing can be deferred to later time, you can utilize [domain events](https://github.com/xhafan/coreddd/wiki/Domain-events) and [publish event messages over a message bus from domain event handlers](https://github.com/xhafan/coreddd/wiki/Domain-events#publishing-event-messages-over-a-message-bus-from-domain-event-handlers), and handle the event messages in a separate process and transaction. Deferring some processing to a later time can make the main request transaction smaller, thus making the request handling shorter. Here are some examples of a processing which can be deferred:

- subsequent domain processing (e.g. when creating an order in an eshop, the billing PDF generation can be done later)  
- sending email
- accessing other web services
 
Let's imagine that when a ship is created we need to verify it's IMO (International Maritime Organization) number using a web service. We won't be accessing a real web service, we will just create a new service `InternationalMaritimeOrganizationVerifier`. Here is a version for .NET 4 Web Forms app:
```c#
public class InternationalMaritimeOrganizationVerifier : IInternationalMaritimeOrganizationVerifier
{
    public bool IsImoNumberValid(string imoNumber)
    {
        // implement ship verification using International Maritime Organization web api
        Thread.Sleep(4000); // sleep 4 seconds to simulate slow web request        
        return true;
    }
}
```
Here is an async version for ASP.NET Core MVC app:
```c#
public class InternationalMaritimeOrganizationVerifier : IInternationalMaritimeOrganizationVerifier
{
    public async Task<bool> IsImoNumberValid(string imoNumber)
    {
        // implement ship verification using International Maritime Organization web api
        await Task.Delay(4000); // sleep 4 seconds to simulate slow web request
        return true;
    }
}
```
Now, when you call the service to verify the IMO number, it will take simulated 4 seconds to return. If you call it directly from the main web request when creating a new ship, the whole request would take 4 seconds to complete. Here is the an example of how it could be done for the Web Forms app. The `Ship` entity:
```c#
public class Ship : Entity, IAggregateRoot
{
    ...
    public virtual string ImoNumber { get; protected set; }
    public virtual bool HasImoNumberBeenVerified { get; protected set; }
    public virtual bool IsImoNumberValid { get; protected set; }

    ...

    public virtual void VerifyImoNumber(IInternationalMaritimeOrganizationVerifier internationalMaritimeOrganizationVerifier)
    {
        IsImoNumberValid = internationalMaritimeOrganizationVerifier.IsImoNumberValid(ImoNumber);
        HasImoNumberBeenVerified = true;
    }
}
```
The command handler:
```c#
public class CreateNewShipCommandHandler : BaseCommandHandler<CreateNewShipCommand>
{
    private readonly IRepository<Ship> _shipRepository;
    private readonly IInternationalMaritimeOrganizationVerifier _internationalMaritimeOrganizationVerifier;

    public CreateNewShipCommandHandler(
        IRepository<Ship> shipRepository,
        IInternationalMaritimeOrganizationVerifier internationalMaritimeOrganizationVerifier
        )
    {
        _internationalMaritimeOrganizationVerifier = internationalMaritimeOrganizationVerifier;
        _shipRepository = shipRepository;
    }

    public override void Execute(CreateNewShipCommand command)
    {
        var newShip = new Ship(command.ShipName, command.Tonnage, command.ImoNumber);
        newShip.VerifyImoNumber(_internationalMaritimeOrganizationVerifier);
        _shipRepository.Save(newShip);

        RaiseCommandExecutedEvent(new CommandExecutedArgs { Args = newShip.Id });
    }
}
```
The code samples are available [here](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/CoreDddShared/Domain/Ship.cs#L54) and [here](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/CoreDddShared/Commands/CreateNewShipCommandHandler.cs#L30).

A better way, which would not block the web request, would be to raise a domain event that a ship has been created, and publish a domain event message to a message bus, and handle the IMO number verification in another process subscribed to handle domain event messages. Here is the an example of how it could be done for the ASP.NET Core MVC app. The `Ship` entity:
```c#
public class Ship : Entity, IAggregateRoot
{
    ...
    public virtual string ImoNumber { get; protected set; }
    public virtual bool HasImoNumberBeenVerified { get; protected set; }
    public virtual bool IsImoNumberValid { get; protected set; }

    ...

    public virtual void OnCreationCompleted()
    {
        if (Id == default(int)) throw new Exception("Id has not been assigned yet - entity creation has not been completed yet");

        DomainEvents.RaiseEvent(new ShipCreatedDomainEvent { ShipId = Id });
    }

    public virtual async Task VerifyImoNumber(IInternationalMaritimeOrganizationVerifier internationalMaritimeOrganizationVerifier)
    {
        IsImoNumberValid = await internationalMaritimeOrganizationVerifier.IsImoNumberValid(ImoNumber);
        HasImoNumberBeenVerified = true;
    }
}
```  
The command handler:
```c#
public class CreateNewShipCommandHandler : BaseCommandHandler<CreateNewShipCommand>
{
    private readonly IRepository<Ship> _shipRepository;

    public CreateNewShipCommandHandler(IRepository<Ship> shipRepository)
    {
        _shipRepository = shipRepository;
    }
    
    public override async Task ExecuteAsync(CreateNewShipCommand command)
    {
        var newShip = new Ship(command.ShipName, command.Tonnage, command.ImoNumber);
        await _shipRepository.SaveAsync(newShip); // Save will generate Id
        newShip.OnCreationCompleted();

        RaiseCommandExecutedEvent(new CommandExecutedArgs { Args = newShip.Id });
    }    
}
```
The domain event handler (using [Rebus](https://www.nuget.org/packages/Rebus/) message bus):
```c#
public class ShipCreatedDomainEventHandler : IDomainEventHandler<ShipCreatedDomainEvent>
{
    private readonly ISyncBus _bus;

    public ShipCreatedDomainEventHandler(ISyncBus bus)
    {
        _bus = bus;
    }

    public void Handle(ShipCreatedDomainEvent domainEvent)
    {
        _bus.Publish(new ShipCreatedDomainEventMessage {ShipId = domainEvent.ShipId});
    }
}
```
The domain event message handler (using [Rebus](https://www.nuget.org/packages/Rebus/), the handler executed in a different process asynchronously):
```c#
public class VerifyImoNumberShipCreatedDomainEventMessageHandler : IHandleMessages<ShipCreatedDomainEventMessage>
{
    private readonly IRepository<Ship> _shipRepository;
    private readonly IInternationalMaritimeOrganizationVerifier _internationalMaritimeOrganizationVerifier;

    public VerifyImoNumberShipCreatedDomainEventMessageHandler(
        IRepository<Ship> shipRepository,
        IInternationalMaritimeOrganizationVerifier internationalMaritimeOrganizationVerifier
        )
    {
        _shipRepository = shipRepository;
        _internationalMaritimeOrganizationVerifier = internationalMaritimeOrganizationVerifier;
    }

    public async Task Handle(ShipCreatedDomainEventMessage message)
    {
        var ship = await _shipRepository.GetAsync(message.ShipId);
        await ship.VerifyImoNumber(_internationalMaritimeOrganizationVerifier);
    }
}
```
Implementing the IMO number verification this way, the web request can complete immediately, and the IMO number will be eventually verified at some point later, usually almost immediately after the web request. The 4 seconds simulated wait in `InternationalMaritimeOrganizationVerifier` will block the domain event message handler.  

The code samples are available here:
- [Ship](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/CoreDddShared/Domain/Ship.cs#L41) entity
- [command handler](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/CoreDddShared/Commands/CreateNewShipCommandHandler.cs#L9)
- [domain event handler](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/CoreDddShared/Domain/Events/ShipCreatedDomainEventHandler.cs)
- [domain event message handler](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/ServiceApp/MessageHandlers/VerifyImoNumberShipCreatedDomainEventMessageHandler.cs)

### <a name="reliable_command_handling"></a>Reliable command handling
So far a command is handled once within the web application process. In the case of a temporary error like a database deadlock, a database timeout, a network connectivity error to a database server, etc., or a permanent error like an application bug, the command handling fails and an error message is shown to a user. For both temporary and permanent errors, the user needs to repeat the action which would send a new command (for permanent errors, the user needs to wait for the application fix). This can be improved by a web application sending the command over a message bus to a service application, where it can be handled reliably with multiple re-tries which could handle the temporary errors automatically be simply re-trying command handling again couple of times. In the case of an application bug, the command handling would fail all handling re-tries, and the command message would be moved into an error message queue. Once the bug is fixed and a new version of the service application is deployed, the command message can be moved back into the input message queue and the command handling would succeed. With the reliable command handling, for both temporary and permanent errors, the user would not have to repeat the action.

Let's see an example of a reliable version of a new ship creation (using packages [Rebus](https://www.nuget.org/packages/Rebus/) and [Rebus.Async](https://www.nuget.org/packages/Rebus.Async)): 
```c#
public class ManageShipsController : Controller
{
    ...
    private readonly IBusRequestSender _busRequestSender;

    public ManageShipsController(
        ...
        IBusRequestSender busRequestSender
        )
    {
        ...
        _busRequestSender = busRequestSender;
    }

    ...

    [HttpPost]
    public async Task<IActionResult> CreateNewShipReliably(CreateNewShipCommand createNewShipCommand)
    {
        var reply = await _busRequestSender.SendRequest<CreateNewShipCommandReply>(createNewShipCommand);

        return RedirectToAction("CreateNewShip", new { lastCreatedShipId = reply.CreatedShipId });
    }
}

public interface IBusRequestSender
{
    Task<TReply> SendRequest<TReply>(object message);
}

public class BusRequestSender : IBusRequestSender
{
    private readonly IBus _bus;
    private readonly double _timeoutInSeconds;

    public BusRequestSender(IBus bus, double timeoutInSeconds = 30)
    {
        _timeoutInSeconds = timeoutInSeconds;
        _bus = bus;
    }

    public async Task<TReply> SendRequest<TReply>(object message)
    {
        return await _bus.SendRequest<TReply>(message, timeout: TimeSpan.FromSeconds(_timeoutInSeconds));
    }
}

```
The new controller method `CreateNewShipReliably` just sends the command over a message bus and waits for a reply. `BusRequestSender` is a small wrapper over Rebus.Async static extension method `SendRequest` to make the code testable. We've done enough TDD for today, so the London style TDD test for the controller method is available [here](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/AspNetCoreMvcApp.Tests/Controllers/ManageShipsControllers/when_creating_new_ship_reliably.cs) for those interested. Just a small note regarding the test - in my opinion the controller method implementation is so dummy, that I'm inclined to ignore testing it completely.
The command message handler in the service application would look like this:
```c#
public class CreateNewShipCommandMessageHandler : IHandleMessages<CreateNewShipCommand>
{
    private readonly ICommandExecutor _commandExecutor;
    private readonly IBus _bus;

    public CreateNewShipCommandMessageHandler(
        ICommandExecutor commandExecutor,
        IBus bus
    )
    {
        _bus = bus;
        _commandExecutor = commandExecutor;
    }

    public async Task Handle(CreateNewShipCommand command)
    {
        var createdShipId = 0;
        _commandExecutor.CommandExecuted += args => createdShipId = (int)args.Args;
        await _commandExecutor.ExecuteAsync(command);

        await _bus.Reply(new CreateNewShipCommandReply {CreatedShipId = createdShipId});
    }
}
```
The test for the command message handler is available [here](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/ServiceApp.IntegrationTests/MessageHandlers/CreateNewShipCommandMessageHandlers/when_handling_create_new_ship_command_message.cs). The command message handler implementation is reusing the existing `CreateNewShipCommandHandler` via the command executor, but it would be possible to implement the command handling logic directly here in the command message handler, and to get rid of `CreateNewShipCommandHandler`.
To plug the new reliable command handling into the AspNetCoreMvcApp, just submit the create a new ship HTML form into the new action method `CreateNewShipReliably` (in [CreateNewShip.cshtml](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/AspNetCoreMvcApp/Views/ManageShips/CreateNewShip.cshtml)):
```xml
...
<form method="post" asp-action="CreateNewShipReliably">
    ...
    <button type="submit" ...>Create new ship</button>
    ...
</form>
...
```
The code samples above are available here:
- [ManageShipsController.CreateNewShipReliably()](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/AspNetCoreMvcApp/Controllers/ManageShipsController.cs#L72)
- [CreateNewShipCommandMessageHandler](https://github.com/xhafan/legacy-to-coreddd/blob/master/src/ServiceApp/CommandMessageHandlers/CreateNewShipCommandMessageHandler.cs)

### Conclusion
Congratulations for making it this far. Hopefully this blog post will help somebody when rewriting a legacy application. The techniques mentioned in this blog post are applicable for a green field development as well. Please share any comment you might have in the discussion below.

----------

### About Me

[Martin Havlišta](https://xhafan.com/blog/about.html) is DDD TDD .NET/C# software developer, interested in modelling complex domains and implementing them using DDD and TDD.