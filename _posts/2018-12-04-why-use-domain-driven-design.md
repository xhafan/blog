---
layout: post
title: Why use domain-driven design
tags: DDD
---
Posted By [Martin Havlišta]({{ site.baseurl }}/about.html)

### A short rant about why domain-driven design (DDD) is good.
<!--more-->

In my opinion the domain-driven design (DDD) allows to express a domain model and a business logic/domain behaviour in the code in the clearest possible object oriented form. DDD defines a standardized approach how to design a domain model, so developers can understand the implementation more easily, and can effectively communicate with each other using the DDD terms. DDD defines terms like an [aggregate root](https://stackoverflow.com/questions/1958621/whats-an-aggregate-root) domain entity, a domain entity, a value object, a repository and [others](https://en.wikipedia.org/wiki/Domain-driven_design#Building_blocks). The domain is modelled using domain entities (object oriented classes)  where the names of the entities in the code reflect the names of the entities in the domain. Example: if there is a policy entity in an insurance domain, there would be a `Policy` class in the code. Also the business logic/domain behaviour is reflected in the code using the name of the behaviour. Example: if the policy needs to calculate invoices, there would be a method `Policy.CalculateInvoices()` in the code. This naming convention is called [Ubiquitous Language](https://martinfowler.com/bliki/UbiquitousLanguage.html), and it forces the developers to use the same business terms in the code as in the discussion with the business users, thus removing the ambiguity. The domain entities are implemented within one [domain/business logic layer](https://martinfowler.com/bliki/PresentationDomainDataLayering.html), which knows nothing about the database persistence (persistence layer) and the user interface (presentation layer). The data are stored within the entities as data properties, and the persistence layer makes sure that these data are correctly persisted into a database, be it SQL or NoSQL database. Here are some libraries which you can use to implement the [transparent persistence](https://stackoverflow.com/a/20863185/379279) layer: [NHibernate](http://nhibernate.info/) for .NET (SQL databases), [Hibernate](http://hibernate.org/) for Java (both SQL and NoSQL databases), [Doctrine](https://www.doctrine-project.org/projects/doctrine-orm/en/2.6/tutorials/getting-started.html) for PHP (SQL databases). The domain entities have a rich behaviour like calculations and validations implemented in them, they are not bags of data properties without any behaviour (an anti-pattern called [anemic domain model](https://www.martinfowler.com/bliki/AnemicDomainModel.html)). Please refer to this [Stack Overflow answer](https://stackoverflow.com/a/1222488/379279) for more details about DDD. 

When using DDD, you first think about the behaviour - what does it do. You first implement the behaviour - methods doing something useful. For instance, when you want to implement an invoice calculation on a policy, you don't start with adding an `Invoice` table into a database. You start with adding an empty domain method `CalculateInvoices()` on the `Policy` entity. Some [TDD](https://en.wikipedia.org/wiki/Test-driven_development) purists would create a test(s) for the invoice calculation even before defining the method. This would force you to add a collection of `Invoice` entities (generated invoices) somewhere into the `Policy` entity or it's sub-entities it manages. After the tests are completed and failing (if you do TDD), you can start implementing the invoice calculation. During the implementation, you might realize that you don't want the invoice collection to sit on the `Policy` entity, but somewhere else - a sub-entity, or an extra entity you created when you implemented the code. When you are done with the implementation, the code looks nice, tests define the expected behaviour, and you use a SQL database, you can use the transparent persistence libraries mentioned in the first paragraph to generate the SQL scripts from your domain entities (object oriented classes) to create the database tables for the new entities you just created during the implementation (here is [NHibernate code sample](https://stackoverflow.com/a/1299550/379279) which generates the SQL schema script). The beauty of this approach is that you create the database tables only when you are done with the domain behaviour implementation, so you are less likely to change the database structure later. In the case you wonder about how will you change the database structure later, when you refactor the entities in the way they no longer map into the current database structure, here are the solutions: 
1. migrate the current database structure into the new structure manually using SQL scripts. I recommend this approach as you can add the migration script into the source code repository, and automate building the database for other developers and for the application deployment. In .NET world, you can use my library [DatabaseBuilder](https://github.com/xhafan/databasebuilder) to implement the migration script automation.
2. or use tools to generate the database structure migration and the data migration scripts (for SQL server you can use [SQL Compare](https://www.red-gate.com/products/sql-development/sql-compare/) to generate the database structure migration script and [SQL Data Compare](https://www.red-gate.com/products/sql-development/sql-data-compare/) to generate the data migration script).
3. In .NET world, [Entity Framework](https://en.wikipedia.org/wiki/Entity_Framework) has a [database migrations](https://docs.microsoft.com/en-us/ef/core/managing-schemas/migrations/) feature.

Another way to design an application is a database-driven design - first designing the database tables with fields, and then implementing the domain entities which map their data properties into the database table fields, and which also contain the database persistence code (a pattern also known as [Active Record](https://www.martinfowler.com/eaaCatalog/activeRecord.html)). But, because the domain entity code contains the database persistence code, it makes the business logic/domain behaviour implementation less clear. Also, the database structure was designed upfront using your best guess, without any actual business logic/domain behaviour implementation. Once you start implementing the domain behaviour, you might find yourself that you need to change the database structure couple of times. For a domain-driven design and a database-driven design comparison, please refer to this [Stack Overflow answer](https://stackoverflow.com/a/308647/379279).  


DDD is suitable for larger projects with a complex domain behaviour, and less suitable for projects without rich behaviour (e.g. projects which just edit a data). Projects which would benefit from DDD would take couple of months/years to develop, would be continuously developed, maintained, and amended as per new business requirements. For such projects, the code in two years time could be quite different from the code when the project was started. Somewhere in the middle of the implementation, when the team gain more domain knowledge, they might realize the initial domain model is not sufficient, and that they need to refactor the code into a slightly different domain model. Refactoring the business logic/domain behaviour code contained within one domain/business logic layer, is easier than refactoring the business logic which is scattered all over the place within the presentation and the persistence layer. If you combine DDD with [Chicago style test-driven development](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd) (TDD), the project you are working on will never become one of those unmaintainable slowly dying projects.

For diving deep into DDD I recommend [Eric Evans's book](https://amzn.to/2E9dRAC).

Here is a practical example of DDD done in an ASP.NET Core MVC sample application using my [CoreDdd](https://github.com/xhafan/coreddd/) .NET library and NHibernate persistence. It's a simple implementation of updating a ship data, using [CQRS](https://martinfowler.com/bliki/CQRS.html) pattern. The controller:
```c#
public class ShipController : Controller
{
    private readonly ICommandExecutor _commandExecutor;
    ...

    public ShipController(
        ICommandExecutor commandExecutor,
        ...
    )
    {
        _commandExecutor = commandExecutor;
        ...
    }
    ...
    public async Task<string> UpdateShipData(int shipId, string shipName, decimal tonnage)
    {
        await _commandExecutor.ExecuteAsync(new UpdateShipDataCommand { ShipId = shipId, ShipName = shipName, Tonnage = tonnage });

        return "Ship data updated.";
    }
}
```
The controller just executes the `UpdateShipDataCommand` command. The code sample is available [here](https://github.com/xhafan/coreddd-sample/blob/master/src/CoreDddSampleAspNetCoreWebApp/Controllers/ShipController.cs).

The command handler of `UpdateShipDataCommand` command:
```c#
public class UpdateShipDataCommandHandler : BaseCommandHandler<UpdateShipDataCommand>
{
    private readonly IRepository<Ship> _shipRepository;

    public UpdateShipDataCommandHandler(IRepository<Ship> shipRepository)
    {
        _shipRepository = shipRepository;
    }

    public override async Task ExecuteAsync(UpdateShipDataCommand command)
    {
        var ship = await _shipRepository.GetAsync(command.ShipId);

        ship.UpdateData(command.ShipName, command.Tonnage);
    }
}
```
The command handler fetches the `Ship` aggregate root domain entity from the repository, and executes the domain method `UpdateData` on it. The code sample is available [here](https://github.com/xhafan/coreddd-sample/blob/master/src/CoreDddSampleWebAppCommon/Commands/UpdateShipDataCommandHandler.cs).

The `Ship` aggregate root domain entity:
```c#
public class Ship : Entity, IAggregateRoot
{
    ...
    public Ship(string name, decimal tonnage)
    {
        Name = name;
        Tonnage = tonnage;
    }

    public string Name { get; private set; }
    public decimal Tonnage { get; private set; }

    public void UpdateData(string name, decimal tonnage)
    {
        Name = name;
        Tonnage = tonnage;
        ...
    }
}
```
The `UpdateData` method just updates the data properties (not a rocket science behaviour here). The code sample is available [here](https://github.com/xhafan/coreddd-sample/blob/master/src/CoreDddSampleWebAppCommon/Domain/Ship.cs). 

Here's how the transparent persistence works. The whole HTTP request is wrapped inside a database transaction which commits at the end of the request. The transaction wrapping is implemented as an ASP.NET Core middleware:
```c#
public class UnitOfWorkDependencyInjectionMiddleware : BaseUnitOfWorkMiddleware
{
    ...
    protected async Task InvokeAsync(HttpContext context, RequestDelegate next, IUnitOfWork unitOfWork)
    {
        unitOfWork.BeginTransaction(_isolationLevel);
        ...
        try
        {
            await next.Invoke(context); // executes the controller method within

            await unitOfWork.CommitAsync(); // applies the changes into the database and commits the transaction
        }
        catch
        {
            await unitOfWork.RollbackAsync();
            throw;
        }
        ...
    }
}
```
The code sample is available [here](https://github.com/xhafan/coreddd/blob/master/src/CoreDdd.AspNetCore/Middlewares/UnitOfWorkDependencyInjectionMiddleware.cs) and [here](https://github.com/xhafan/coreddd/blob/master/src/CoreDdd.AspNetCore/Middlewares/BaseUnitOfWorkMiddleware.cs). NHibernate fetched the `Ship` entity from the database, registered the entity in its session, during the commit it detected if there were data changes on the entity, and if yes it issued a SQL UPDATE statement to update the `Ship` table. 

If you are interested in more complex DDD sample, you can checkout the [DDD sample](https://github.com/xhafan/coreddd/wiki/DDD-sample) from the [CoreDdd documentation](https://github.com/xhafan/coreddd/wiki), or you can checkout another [blog post]({{ site.baseurl }}/2018/12/04/rewrite-a-legacy-application-using-ddd-tdd-.net-and-coreddd-library.html) of mine about rewriting a legacy application using DDD, CQRS, TDD and CoreDdd.

Please share any comment you might have in the discussion below. Thank you for reading!