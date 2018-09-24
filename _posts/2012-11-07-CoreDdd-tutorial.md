---
layout: post
title: CoreDdd tutorial - real life DDD/TDD ASP.NET MVC and WPF application built on CoreDdd library
---

_This article is for legacy CoreDdd [version 1.7.1.1](https://www.nuget.org/packages/CoreDdd/1.1.7.1). There is a newer CoreDdd [version 3](https://www.nuget.org/packages/CoreDdd), with a documentation and samples [here](https://github.com/xhafan/coreddd/wiki). Also this tutorial uses [London style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd) which I used at the point of writing this article (~2012), but since then I switched to [Chicago style TDD](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd), and now I consider the TDD code samples in this article as a legacy code._
  

In a [previous article]({{ site.baseurl }}/do-you-want-to-write-readable-maintainable-code-use-ddd-tdd-cqrs-ioc) you can read more about a motivation behind CoreDdd library. Application we are going to build on [CoreDdd](http://nuget.org/packages/CoreDdd) library is an e-shop, source code [here](http://code.google.com/p/eshop-coreddd).  Initially it's going to be a simplified version, but agile process enables you to iteratively add more features, DDD/TDD/CQRS/patterns & principles ensure not to plunge into a spaghetti waterfall code, and as you learn the business/domain as you go along, you can safely refactor if required and take the project to a more mature version. Initial version of the e-shop application would contain:
<!--more-->

1. Display a list of products
2. Add a product into a basket/remove product from a basket
3. Display basket items
4. Buy basket items
5. No customer login, each customer will be assigned customer Id dynamically for the length of a session

This article is divided into following sections:

1. [Domain](#domain)
    1. [Domain behaviour](#domain_behaviour)
    2. [Persistence](#domain_persistence)
2. [Commands](#commands)
3. [Queries](#queries)

# <a id="domain"></a>Domain
## <a id="domain_behaviour"></a>Domain behaviour
From these initial basic requirements, we can start modelling the domain. Let's start with domain entities which actually have some behaviour so far. We will remember `Customer`'s basket content on a server, so we would need `Customer` aggregate root entity with domain methods:

* `AddProductToBasket`
* `UpdateProductCountInBasket`
* `SetDeliveryAddress`
* `PlaceOrder` which would create a new `Order` entity. 

So far I can't think of any other domain entity with some behaviour.  As you can see I started with the behaviour domain modelling first because I have some basic UI wireframes in my head and I've seen many e-shops and I know which behaviour I'm going to need. But, if you don't know any domain actions/behaviour, or you don't know UI or if the application doesn't have UI, you need to know what is the actual useful behaviour needed - talk to business people what kind of actions they do in the system, or figure it out yourself, you can always refactor it if you get it wrong at the first go.

Now that we know what we want to do, install Visual Studio 2010 or 2012. A better option is a full version of Visual Studio instead of Express edition as you can optionally install [Resharper](http://www.jetbrains.com/resharper/) plugin to speed up refactoring (renaming classes, properties, moving classes around, searching for usages of classes, methods, etc). For Visual Studio 2010, install [NuGet](http://nuget.org).

Create a new blank solution, call it Eshop, add a new class library project and call it Eshop.Domain. Right click the project, select *Manage NuGet Packages*, click *Online*, search for *CoreDdd*, click install. Delete *App_Start* folder and Class1.cs file. Create a new classes `Customer` and `Product` derived from `Entity` (namespace CoreDdd.Domain) and implementing `IAggregateRoot` interface which marks aggregate root entities. Add method `AddProductToBasket(Product product, int count)` to `Customer`, leave the body empty:

    public class Customer : Entity, IAggregateRoot
    {
        public void AddProductToBasket(Product product, int count)
        {            
        }
    }

Create a new project called Eshop.UnitTests, reference CoreTest, Shouldly libraries via NuGet. Delete file Class1.cs, add folders Domain/Customers ('s' at the end so the namespace doesn't collide with the class name), add a new testfixture class called `when_adding_product_to_basket` derived from CoreTest's `BaseTest` with following body:

    [TestFixture]
    public class when_adding_product_to_basket : BaseTest
    {
        [SetUp]
        public void Context()
        {            
        }

        [Test]
        public void product_is_added()
        {
        }
    }

You can add a testfixture body via following Resharper template:

    [TestFixture]
    public class $TestFixture$ : BaseTest
    {
        [SetUp]
        public void Context()
        {
            $END$
        }

        [Test]
        public void $TestName$()
        {
        }
    }

In the Context method, instantiate `Customer`, and call the act (=tested method) `AddProductToBasket` on it with stubbed `Product`:

        [SetUp]
        public void Context()
        {
            var customer = new Customer();

            customer.AddProductToBasket(Stub<Product>(), 23);
        }

It could be called with a real instance of `Product`, but first we want to test `Customer` methods in an isolation from other concrete classes, and next, if somebody adds a constructor with parameters into Product, we would need to change this test. 
`Customer` will have a collection of basket items. We need to add a new class `BasketItem` derived from `Entity`, **don't** implement `IAggregateRoot` interface as `BasketItem` is not an aggregate root entity, it's just an entity dependent on another aggregate root entity, in this case `Customer`. `BasketItem` will be referencing a `Product` and count of products:

    public class Customer : Entity, IAggregateRoot
    {
        private readonly Iesi.Collections.Generic.ISet<BasketItem> _basketItems = new HashedSet<BasketItem>();
        public IEnumerable<BasketItem> BasketItems { get { return _basketItems; } }
        ...
    }

    public class BasketItem : Entity
    {
        public Product Product { get; private set; }
        public int Count { get; private set; }
    }

This needs a bit of explanation. DDD says that a domain entity can change a state only via domain method call. So, to forbid calling `Add` method on public `ISet<BasketItem>` property we need to make it private and add `IEnumerable<BasketItem>` getter. `Iesi.Collections.Generic.ISet` and `Iesi.Collections.Generic.HashedSet` are used by NHibernate later for persistence.

Now we can implement the test:

    [TestFixture]
    public class when_adding_product_to_basket : BaseTest
    {
        private const int Count = 23;
        private Customer _customer;
        private Product _product;

        [SetUp]
        public void Context()
        {
            _product = Stub<Product>();
            _customer = new Customer(); 

            _customer.AddProductToBasket(_product, Count);
        }

        [Test]
        public void product_is_added()
        {
            _customer.BasketItems.Count().ShouldBe(1);
            var basketItem = _customer.BasketItems.First();
            basketItem.Product.ShouldBe(_product);
            basketItem.Count.ShouldBe(Count);
        }
    }

Run the test via NUnit runner (install NUnit.Runners via NuGet, run packages/NUnit.Runners.x.x.x/tools/nunit.exe and open Eshop.UnitTests.dll) or Resharper, it should fail with a correct reason; implement the body of the tested method. During the implementation you realize that you need a constructor with parameters on `BasketItem`:

        public BasketItem(Product product, int count)
        {
        }

As we are doing TDD, we need to create a test for this constructor first:

    [TestFixture]
    public class when_creating_basket_item : BaseTest
    {
        private const int Count = 23;
        private BasketItem _basketItem;
        private Product _product;

        [SetUp]
        public void Context()
        {
            _product = Stub<Product>();

            _basketItem = new BasketItem(_product, Count);
        }

        [Test]
        public void properties_are_correctly_set()
        {
            _basketItem.Product.ShouldBe(_product);
            _basketItem.Count.ShouldBe(Count);
        }
    }

Once this test is correctly failing, implement `BasketItem` constructor:

        public BasketItem(Product product, int count)
        {
            Product = product;
            Count = count;
        }

Test should be passing. Now we can implement original `AddProductToBasket` method we are testing:

        public void AddProductToBasket(Product product, int count)
        {
            _basketItems.Add(new BasketItem(product, count));
        }

Test for it should be passing now. We need to implement one more case "add another product of the same type" which should not create another basket item but update a count in existing one:

    [TestFixture]
    public class when_adding_another_product_of_the_same_type_to_basket : BaseTest
    {
        private const int Count = 23;
        private Customer _customer;
        private Product _product;
        private BasketItem _basketItem;

        [SetUp]
        public void Context()
        {
            _product = Stub<Product>();
            _customer = new Customer();
            _basketItem = Mock<BasketItem>()
                .Stubs(x => x.Product).Returns(_product)
                .Stubs(x => x.Count).Returns(1);
            _customer.BasketItems.AsSet().Add(_basketItem);

            _customer.AddProductToBasket(_product, Count);
        }

        [Test]
        public void product_count_is_updated()
        {
            _customer.BasketItems.Count().ShouldBe(1);
            _basketItem.AssertWasCalled(x => x.AddCount(Count));
        }
    }

This forced us to add `AddCount` method into `BasketItem`: 

        public virtual void AddCount(int count)
        {
            Count += count;
        }

With the following test:

    [TestFixture]
    public class when_adding_count : BaseTest
    {
        private BasketItem _basketItem;

        [SetUp]
        public void Context()
        {
            _basketItem = new BasketItem(Stub<Product>(), 1);

            _basketItem.AddCount(1);
        }

        [Test]
        public void count_is_updated()
        {
            _basketItem.Count.ShouldBe(2);
        }
    }

Again, `when_adding_another_product_of_the_same_type_to_basket` should be failing first on a correct reason, and following implementation of `AddProductToBasket` method will make it pass:

        public void AddProductToBasket(Product product, int count)
        {
            var basketItemWithTheProduct = _basketItems.FirstOrDefault(x => x.Product == product);
            if (basketItemWithTheProduct != null)
            {
                basketItemWithTheProduct.AddCount(count);
            }
            else
            {
                _basketItems.Add(new BasketItem(product, count));
            }
        }

Couple of hidden things needed to be done. `BasketItem` got protected empty constructor so it could be mocked by `Mock<BasketItem>()`. Properties `Product` and `Count` were made virtual in order to stub them. `AddCount` method was made virtual in order to use `AssertWasCalled` for it. 

So, is it worth testing it like this? For couple of line of code so many lines of test code. Just realize this is the first version of `AddProductToBasket` method, later you might add more complex domain logic like "set free delivery flag if basket content > £50", or "set discount for more than 10 items of one product", etc and only then when the code becomes really complex these tests become very handy. In most cases to create testfixtures quickly, you can use a) Resharper to create a new testfixture from a template, or b) you can use Resharper's feature *Copy Type* (CTRL+SHIFT+R, C) to create a copy of existing testfixture to create a new testfixture, modify few things and quickly be done. 

In the same way we will implement `UpdateProductCountInBasket` method. Tests:

    [TestFixture]
    public class when_updating_product_count_in_basket : BaseTest
    {
        private Customer _customer;
        private BasketItem _basketItem;
        private const int NewCount = 34;

        [SetUp]
        public void Context()
        {
            _customer = new Customer();
            var product = Stub<Product>();
            _basketItem = Mock<BasketItem>().Stubs(x => x.Product).Returns(product);
            _customer.BasketItems.AsSet().Add(_basketItem);

            _customer.UpdateProductCountInBasket(product, NewCount);
        }

        [Test]
        public void count_is_updated_for_product()
        {
            _basketItem.AssertWasCalled(x => x.UpdateCount(NewCount));
        }
    }

    [TestFixture]
    public class when_updating_product_count_in_basket_to_zero : BaseTest
    {
        private Customer _customer;

        [SetUp]
        public void Context()
        {
            _customer = new Customer();
            var product = Stub<Product>();
            var basketItem = Stub<BasketItem>().Stubs(x => x.Product).Returns(product);
            _customer.BasketItems.AsSet().Add(basketItem);

            _customer.UpdateProductCountInBasket(product, 0);
        }

        [Test]
        public void basket_item_is_removed()
        {
            _customer.BasketItems.ShouldBeEmpty();
        }
    }

Domain method:

        public virtual void UpdateProductCountInBasket(Product product, int newCount)
        {
            var basketItem = _basketItems.First(x => x.Product == product);
            if (newCount == 0)
            {
                _basketItems.Remove(basketItem);
            }
            else
            {
                basketItem.UpdateCount(newCount);
            }
        }

and SetDeliveryAddress method. Test:

    [TestFixture]
    public class when_setting_delivery_address : BaseTest
    {
        private const string DeliveryAddress = "delivery address";
        private Customer _customer;

        [SetUp]
        public void Context()
        {
            _customer = new Customer();

            _customer.SetDeliveryAddress(DeliveryAddress);
        }

        [Test]
        public void delivery_address_is_set()
        {
            _customer.DeliveryAddress.ShouldBe(DeliveryAddress);  
        }
    }

Domain method:

        public void SetDeliveryAddress(string deliveryAddress)
        {
            DeliveryAddress = deliveryAddress;
        }

`PlaceOrder` method will create a new `Order` entity and will move basket items into Order. 
`Order` entity:

    public class Order : Entity, IAggregateRoot
    {
        private readonly Iesi.Collections.Generic.ISet<OrderItem> _orderItems = new HashedSet<OrderItem>();
        public IEnumerable<OrderItem> OrderItems { get { return _orderItems; } }

        public string DeliveryAddress { get; private set; }
    }

`PlaceOrder` test:

    [TestFixture]
    public class when_placing_order : BaseTest
    {
        private const string DeliveryAddress = "delivery address";
        private Customer _customer;
        private Order _order;

        [SetUp]
        public void Context()
        {
            _customer = new Customer();
            var basketItem = Stub<BasketItem>();
            _customer.BasketItems.AsSet().Add(basketItem);
            _customer.DeliveryAddress = DeliveryAddress;

            _order = _customer.PlaceOrder();
        }

        [Test]
        public void order_contains_basket_items()
        {
            _order.OrderItems.Count().ShouldBe(1);
        }
        
        [Test]
        public void delivery_address_is_set()
        {
            _order.DeliveryAddress.ShouldBe(DeliveryAddress);
        }

        [Test]
        public void basket_is_empty()
        {
            _customer.BasketItems.ShouldBeEmpty();
        }
    }

`DeliveryAddress` property setter was made `internal` together with adding `[assembly: InternalsVisibleTo("Eshop.UnitTests")]` to AssemblyInfo.cs for Eshop.Domain project so we can set property `DeliveryAddress` from the test. `PlaceOrder` test for missing delivery address:

    [TestFixture]
    public class when_placing_order_without_delivery_address : BaseTest
    {
        private Customer _customer;
        private Exception _exception;

        [SetUp]
        public void Context()
        {
            _customer = new Customer();

            _exception = Should.Throw<CoreException>(() => _customer.PlaceOrder());
        }

        [Test]
        public void exception_is_thrown()
        {
            _exception.Message.ShouldBe(Customer.MissingDeliveryAddressExceptionMessage);
        }
    }

Domain method:

        public Order PlaceOrder()
        {
            Guard.Hope(!string.IsNullOrWhiteSpace(DeliveryAddress), MissingDeliveryAddressExceptionMessage);

            var order = new Order(_basketItems, DeliveryAddress);
            _basketItems.Clear();
            return order;
        }

`Order` constructor and test had to be implemented as well:

    [TestFixture]
    public class when_creating_order : BaseTest
    {
        private Product _product;
        private Order _order;
        private const int Count = 23;
        private const string DeliveryAddress = "delivery address";

        [SetUp]
        public void Context()
        {
            _product = Stub<Product>();
            var basketItem = Stub<BasketItem>()
                .Stubs(x => x.Product).Returns(_product)
                .Stubs(x => x.Count).Returns(Count);
            _order = new Order(new[] { basketItem }, DeliveryAddress);
        }

        [Test]
        public void order_items_are_copied_from_basket_items()
        {
            _order.OrderItems.Count().ShouldBe(1);
            var orderItem = _order.OrderItems.First();
            orderItem.Product.ShouldBe(_product);
            orderItem.Count.ShouldBe(Count);
        }

        [Test]
        public void delivery_address_is_set()
        {
            _order.DeliveryAddress.ShouldBe(DeliveryAddress);
        }
    }

`Order` constructor:

        public Order(IEnumerable<BasketItem> basketItems, string deliveryAddress)
        {
            _orderItems.AddAll(basketItems.Select(x => new OrderItem(x.Product, x.Count)).ToList());
            DeliveryAddress = deliveryAddress;
        }

That's all for now for a domain behavior for current requirements. 

## <a id="domain_persistence"></a>Domain persistence
Let's implement integration tests for domain entity DB persistence via NHibernate. Add a new class library project into the solution called Eshop.IntegrationTests, reference CoreTest and Shouldly libraries via NuGet, remove App_Start folder and Class1.cs file, add folder Database and add a new class `EshopAggregateRootTypesToClearProvider` implementing `IAggregateRootTypesToClearProvider` interface, implement `GetAggregateRootTypesToClear` method:

    public class EshopAggregateRootTypesToClearProvider : IAggregateRootTypesToClearProvider
    {
        public IEnumerable<Type> GetAggregateRootTypesToClear()
        {
            yield return typeof(Order);
            yield return typeof(Customer);
            yield return typeof(Product);
        }
    }

Each integration test will be running on an empty test database, and this class is defining which aggregate root entities will be deleted (so which tables will be cleared) before each testfixture run. Add a new abstract class `BaseEshopPersistenceTest` derived from `BasePersistenceTest`, implement just `GetAggregateRootTypesToClear` method:

    public abstract class BaseEshopPersistenceTest : BasePersistenceTest
    {
        protected override IAggregateRootTypesToClearProvider GetAggregateRootTypesToClearProvider()
        {
            return new EshopAggregateRootTypesToClearProvider();
        }
    }

Add another new abstract class `BaseEshopSimplePersistenceTest` derived from `BaseSimplePersistenceTest`, implement just `GetAggregateRootTypesToClear` method:

    public abstract class BaseEshopSimplePersistenceTest : BaseSimplePersistenceTest
    {
        protected override IAggregateRootTypesToClearProvider GetAggregateRootTypesToClearProvider()
        {
            return new EshopAggregateRootTypesToClearProvider();
        }
    }

These two base classes will be used by all persistence integration tests. Add a new class `when_persisting_customer` derived from `BaseEshopSimplePersistenceTest`. This will force us to override `PersistenceContext` and `PersistenceQuery` methods. Implement `Customer` persistence integration test:

    [TestFixture]
    public class when_persisting_customer : BaseEshopSimplePersistenceTest
    {
        private Customer _customer;
        private Customer _retrievedCustomer;

        protected override void PersistenceContext()
        {
            _customer = new Customer();
            Save(_customer);
        }

        protected override void PersistenceQuery()
        {
            _retrievedCustomer = Get<Customer>(_customer.Id);
        }

        [Test]
        public void customer_is_retrieved()
        {
            _retrievedCustomer.ShouldBe(_customer);
        }
    }

When we run this test now, it will fail with an exception `UnitOfWork.Initialize(...)` needs to be called first. `UnitOfWork` class is a wrapper around NHibernate ISession and ISessionFactory used for database access. We need to initialize `UnitOfWork` for the main application and integration tests project, so let's create a reusable class to for this purpose called `UnitOfWorkInitializer`, place it into a new class library project called Eshop.Infrastructure:

    public static class UnitOfWorkInitializer
    {
        public static void Initialize()
        {
            UnitOfWork.Initialize(GetNhibernateConfigurator());
        }

        public static INhibernateConfigurator GetNhibernateConfigurator()
        {
            var assembliesToMap = new List<Assembly> { typeof(Customer).Assembly };
            return new NhibernateConfigurator(assembliesToMap.ToArray(), new[] {typeof (Entity<>) }, new Type[0], true, null);
        }
    }

We are configuring NHibernate to be able to persist into/from database all entities derived from `Entity<TId>` from Eshop.Domain assembly (`typeof(Customer).Assembly`) using default NHibernate conventions provided by CoreDdd (`true` parameter). Its method `Initialize()` need to be called once for an integration test run. In order to do this, add a new *setup fixture* (run once per test run) class called `RunOncePerTestRun` into integration tests project:

    [SetUpFixture]
    public class RunOncePerTestRun
    {
        [SetUp]
        public void SetUp()
        {
            UnitOfWorkInitializer.Initialize();
        }
    }

When we run `when_persisting_customer` test again, it will complain about missing *hibernate.cfg.xml* file. Let's add it to integration tests project:

    <?xml version="1.0" encoding="utf-8" ?>
    <hibernate-configuration xmlns="urn:nhibernate-configuration-2.2">
      <session-factory>
        <property name="connection.provider">NHibernate.Connection.DriverConnectionProvider</property>
        <property name="dialect">NHibernate.Dialect.MsSql2008Dialect</property>
        <property name="connection.driver_class">NHibernate.Driver.SqlClientDriver</property>
        <property name="connection.connection_string_name">EshopConnection</property>
        <property name="show_sql">false</property>
        <property name="proxyfactory.factory_class">NHibernate.Bytecode.DefaultProxyFactoryFactory, NHibernate</property>
      </session-factory>
    </hibernate-configuration>

In properties of this file, set *Copy to Output Directory* to *Copy if newer*. Modify *dialect* and *connection.driver_class* values to match your database (check namespaces `NHibernate.Dialect` and `NHibernate.Driver`). Now the test would complain that entities public methods and properties needs to be virtual (for NHibernate lazy loading) and each entity must have default public or protected parameterless constructor, and property setters needs to be at least protected. We need to modify all domain entities, example:

    public class Order : Entity, IAggregateRoot
    {
        ...
        public virtual IEnumerable<OrderItem> OrderItems { get { return _orderItems; } }

        public virtual string DeliveryAddress { get; protected set; }

        protected Order() {}

        public Order(IEnumerable<BasketItem> basketItems, string deliveryAddress)
        {
            ...
        }
    }

Now the test would complain about missing connection string *EshopConnection*. Add following App.config file into integration tests project:

    <?xml version="1.0" encoding="utf-8" ?>
    <configuration>
      <connectionStrings configSource="connectionStrings.config" />      
    </configuration>

Add following connectionStrings.config file into integration tests project:

    <?xml version="1.0" encoding="utf-8" ?>
    <connectionStrings>
      <add name="EshopConnection" connectionString="Data Source=(local);Initial Catalog=EshopTest;Trusted_Connection=True;" />
    </connectionStrings>

In properties of connectionStrings.config file set *Copy to Output directory* to *copy if newer*. Update the connection string to match your database, optionally replace *Trusted_Connection=True;* by a username and a password. Create a new database called *EshopTest* for integration testing. We will create a real application database called *Eshop* later as it's not needed now. The test should now complain about missing table Order which is kind of correct when there are no tables in the database. All we need to do is generate database create script from existing domain entities. To do this, add a new class called `EshopDatabaseSchemaGenerator` derived from `DatabaseSchemaGenerator` into Eshop.Infrastructure project, with following body:

    public class EshopDatabaseSchemaGenerator : DatabaseSchemaGenerator
    {
        private readonly string _databaseSchemaFileName;

        public EshopDatabaseSchemaGenerator(string databaseSchemaFileName)
        {
            _databaseSchemaFileName = databaseSchemaFileName;
        }


        protected override string GetDatabaseSchemaFileName()
        {
            return _databaseSchemaFileName;
        }

        protected override INhibernateConfigurator GetNhibernateConfigurator()
        {
            return UnitOfWorkInitializer.GetNhibernateConfigurator();
        }
    }

Add a new console application project called `Eshop.DatabaseGenerator` with following `Program.Main` method implementation:

        static void Main(string[] args)
        {
            var schemaGenerator = new EshopDatabaseSchemaGenerator(@"eshop_generated_database_schema.sql");
            schemaGenerator.Generate();
        }

Update target framework of the project from *.NET Framework X Client Profile* to just *.NET Framework X*. Reference NHibernate, NHibernate Profiler, FluentNHibernate, Castle.Windsor libraries via NuGet (delete App_Start folder and remove `App_Start.NHibernateProfilerBootstrapper.PreStart();` line from `Program` class. Add an linked reference to hibernate.cfg.xml (add existing item, browse for hibernate.cfg.xml, and select *add as link*), in properties of the file set *Copy to Output directory* to *copy if newer*. Add following line into App.Config file for Eshop.DatabaseGenerator project:

    <connectionStrings configSource="connectionStrings.config" />

Add an linked reference to connectionStrings.config for Eshop.DatabaseGenerator project, set *Copy to Output directory* to *copy if newer* for it. Run Eshop.DatabaseGenerator application, it should generate `eshop_generated_database_schema.sql` file in bin\Debug folder. Run the script for EshopTest database, it should create all tables. Now run `when_persisting_customer` test, it would fail on exception that `DeliveryAddress` is not nullable (in CoreDdd there are couple of default Fluent NHibernate automap conventions and one of the them is not nullable fields by default). As we want `DeliveryAddress` to be nullable (the delivery address would be set at a later stage), we need to add custom mapping for `Customer` entity and set `DeliveryAddress` to be nullable. This is done by adding a new class derived from IAutoMappingOverride<Customer> next to `Customer` class:

    public class CustomerAutoMap : IAutoMappingOverride<Customer>
    {
        public void Override(AutoMapping<Customer> mapping)
        {
            mapping.Map(x => x.DeliveryAddress).Nullable();
        }
    }

This can be added via following Resharper template:

    public class $ClassName$AutoMap : IAutoMappingOverride<$ClassName$>
    {
        public void Override(AutoMapping<$ClassName$> mapping)
        {
            mapping.$END$
        }
    }

Regenerate the database create script, run it in the test database to recreate it and run `when_persisting_customer` again, it should be passing now. Hurray, we had to do hundred steps to make one persistence test passing. Don't worry, these steps had to be implemented only once.
Now we need to test persistence of `DeliveryAddress` property and `BasketItems` collection. We need to add `[assembly:InternalsVisibleTo("Eshop.IntegrationTests")]` to AssemblyInfo.cs for Eshop.Domain in order to set `DeliveryAddress` property:

    [TestFixture]
    public class when_persisting_customer : BaseEshopSimplePersistenceTest
    {
        private const string DeliveryAddress = "delivery address";
        private Customer _customer;
        private Customer _retrievedCustomer;
        private Product _product;
        private BasketItem _basketItem;
        private const int Count = 23;

        protected override void PersistenceContext()
        {
            _product = new Product();
            _customer = new Customer { DeliveryAddress = DeliveryAddress };
            _basketItem = new BasketItem(_product, Count);
            _customer.BasketItems.AsSet().Add(_basketItem);
            Save(_product, _customer);
        }

        protected override void PersistenceQuery()
        {
            _retrievedCustomer = Get<Customer>(_customer.Id);
        }

        [Test]
        public void properties_are_correctly_set()
        {
            _retrievedCustomer.ShouldBe(_customer);
            _retrievedCustomer.DeliveryAddress.ShouldBe(_customer.DeliveryAddress);
        }

        [Test]
        public void basket_items_are_retrieved_correctly()
        {
            _retrievedCustomer.BasketItems.Count().ShouldBe(1);
            var basketItem = _retrievedCustomer.BasketItems.First();
            basketItem.ShouldBe(_basketItem);
            basketItem.Product.ShouldBe(_product);
            basketItem.Count.ShouldBe(Count);
        }
    }

When you run this updated version of `when_persisting_customer` now, `basket_items_are_retrieved_correctly` test would fail on zero basket items. You can run NHibernate Profiler (packages\NHibernateProfiler.x.x.x.x\tools\NHProf.exe) to check what is going on. Run `when_persisting_customer` test again with the profiler running, you could notice following SQL statement:

    INSERT INTO [BasketItem]
                (Count,
                 ProductId,
                 Id)
    VALUES      (23 /* @p0_0 */,
                 1111 /* @p1_0 */,
                 1313 /* @p2_0 */)

When basket item is inserted into database, `CustomerId` field is not set and is left null. If you check the generated database create script, you could see that `CustomerId` field on BasketItem table is nullable:

    create table [BasketItem] (
       ...
       CustomerId INT null,
       ...
    )

and that foreign key constraint is not named properly:

    alter table [BasketItem] 
        add constraint FK729387BDA68E9456 
        foreign key (CustomerId) 
        references [Customer]

This is caused by implicit parent-child relationship between `Customer` and `BasketItem` entity (that is `BasketItem` not referencing `Customer` via property), and a default CoreDdd *inverse* NHibernate mapping of collections. This needs explanation. By default, in NHibernate, collections are **not** mapped as inverse which means a parent entity is responsible for maintaining the relationship with its children. This is done by NHibernate generating extra update SQL statement after the child insert (without setting the parent) where the parent reference is updated. If CoreDdd would not enforce *inverse* collection mapping, the SQL statements generated would be:

    -- statement #1
    INSERT INTO [BasketItem]
                (Count,
                 ProductId,
                 Id)
    VALUES      (23 /* @p0_0 */,
                 8282 /* @p1_0 */,
                 8484 /* @p2_0 */)

    -- statement #2
    UPDATE [BasketItem]
    SET    CustomerId = 8383 /* @p0_0 */
    WHERE  Id = 8484 /* @p1_0 */

It would insert child entity without setting the parent, and then update the record to set the parent. Insert/update sequence is prevented by default CoreDdd *inverse* collection mapping. But, with *inverse* mapping the child insert is not setting `CustomerId` field. To fix this, we need to reference `Customer` entity from `BasketItem` entity:

        ...
        public BasketItem(Customer customer, Product product, int count)
        {
            Customer = customer;
            ...
        }

        public virtual Customer Customer { get; protected set; }
        ...

After you update tests, and regenerate database create script, you can see the script issues are fixed:

    create table [BasketItem] (
       ...
       CustomerId INT not null,
       ...
    )

    alter table [BasketItem] 
        add constraint FK_BasketItem_Customer 
        foreign key (CustomerId) 
        references [Customer]

Run the whole database create script in the test database again, re-run `when_persisting_customer` following updated version:

    [TestFixture]
    public class when_persisting_customer : BaseEshopSimplePersistenceTest
    {
        private const string DeliveryAddress = "delivery address";
        private Customer _customer;
        private Customer _retrievedCustomer;
        private Product _product;
        private BasketItem _basketItem;
        private const int Count = 23;

        protected override void PersistenceContext()
        {
            _product = new Product();
            _customer = new Customer { DeliveryAddress = DeliveryAddress };
            _basketItem = new BasketItem(_customer, _product, Count);
            _customer.BasketItems.AsSet().Add(_basketItem);
            Save(_product, _customer);
        }

        protected override void PersistenceQuery()
        {
            _retrievedCustomer = Get<Customer>(_customer.Id);
        }

        [Test]
        public void properties_are_correctly_set()
        {
            _retrievedCustomer.ShouldBe(_customer);
            _retrievedCustomer.DeliveryAddress.ShouldBe(_customer.DeliveryAddress);
        }

        [Test]
        public void basket_items_are_retrieved_correctly()
        {
            _retrievedCustomer.BasketItems.Count().ShouldBe(1);
            var basketItem = _retrievedCustomer.BasketItems.First();
            basketItem.ShouldBe(_basketItem);
            basketItem.Customer.ShouldBe(_customer);
            basketItem.Product.ShouldBe(_product);
            basketItem.Count.ShouldBe(Count);
        }
    }

It should be passing now. Next, we need to add persistence tests for remaining entities. `Product`:

    [TestFixture]
    public class when_persisting_product : BaseEshopSimplePersistenceTest
    {
        private Product _product;
        private Product _retrievedProduct;

        protected override void PersistenceContext()
        {
            _product = new Product();
            Save(_product);
        }

        protected override void PersistenceQuery()
        {
            _retrievedProduct = Get<Product>(_product.Id);
        }

        [Test]
        public void retrieved_product_is_the_same()
        {
            _retrievedProduct.ShouldBe(_product);
        }
    }

`Order` (the same issue here - parent `Order` entity needs to be referenced from `OrderItem` entity):

    [TestFixture]
    public class when_persisting_order : BaseEshopSimplePersistenceTest
    {
        private const string DeliveryAddress = "delivery address";
        private const int Count = 23;
        private Order _order;
        private Order _retrievedOrder;
        private Product _product;
        private OrderItem _orderItem;

        protected override void PersistenceContext()
        {
            _product = new Product();
            _order = new Order { DeliveryAddress = DeliveryAddress };
            _orderItem = new OrderItem(_order, _product, Count);
            _order.OrderItems.AsSet().Add(_orderItem);
            Save(_product, _order);
        }

        protected override void PersistenceQuery()
        {
            _retrievedOrder = Get<Order>(_order.Id);
        }

        [Test]
        public void properties_are_correctly_set()
        {
            _retrievedOrder.ShouldBe(_order);
            _retrievedOrder.DeliveryAddress.ShouldBe(_order.DeliveryAddress);
        }

        [Test]
        public void order_items_are_retrieved_correctly()
        {
            _retrievedOrder.OrderItems.Count().ShouldBe(1);
            var orderItem = _retrievedOrder.OrderItems.First();
            orderItem.ShouldBe(_orderItem);
            orderItem.Order.ShouldBe(_order);
            orderItem.Product.ShouldBe(_product);
            orderItem.Count.ShouldBe(Count);
        }
    }

All integration tests should be passing now.

As you can see we need to test mapping of child non-aggregate root entities in the persistence test for parent aggregate root entity as we are able to directly load only aggregate roots from database as prescribed by DDD.

There are couple of default NHibernate conventions in CoreDdd library (`CoreDdd.Infrastructure.Conventions` namespace) which ensure the generated database create script looks reasonable:

* primary key is mapped into `Id` column
* foreign key column is named `<entity name>Id`
* by default not nullable columns
* foreign keys are properly named

We are done so far with domain part, let's implement commands. 

# <a id="commands"></a>Commands
For each action in the system we are going to have a command and a command handler. The main purpose of a command handler is to instantiate via repository or create a new domain aggregate root entity, and call a domain method on it. Add a new class library project called Eshop.Commands into the solution, reference CoreDdd, add a class `AddProductCommand` implementing `ICommand`, add properties `CustomerId`, `ProductId` and `Count`:

    public class AddProductCommand : ICommand
    {
        public int CustomerId { get; set; }
        public int ProductId { get; set; }
        public int Count { get; set; }
    }

Add a new class `AddProductCommandHandler` derived from `BaseCommandHandler<AddProductCommand>`:

    public class AddProductCommandHandler : BaseCommandHandler<AddProductCommand>
    {
        public AddProductCommandHandler(
            IRepository<Customer> customerRepository,
            IRepository<Product> productRepository,
            ICustomerFactory customerFactory)
        {            
        }

        public override void Execute(AddProductCommand command)
        {
        }
    }

Add a new interface `ICustomerFactory`:

    public interface ICustomerFactory
    {
        Customer Create();
    }

to create a new `Customer`. It helps unit testing as we can assert that a method was called on the returned `Customer` instance which would be impossible if we would create the instance via `new Customer()` inside the command handler. 

For `AddProductCommandHandler`, we need to get a customer entity for given CustomerId from a repository, if  the customer doesn't exist, create a new `Customer` entity, and call `AddProductToBasket` on it. As a rigorous TDD developers, we will start with a test first. We actually need two testfixtures in new Eshop.UnitTests\Commands folder. The first one is for a new customer:

    [TestFixture]
    public class when_handling_add_product_to_basket_command_for_new_customer : BaseTest
    {
        private const int Count = 34;
        private Customer _customer;
        private IRepository<Customer> _customerRepository;
        private Product _product;

        [SetUp]
        public void Context()
        {
            _customerRepository = Mock<IRepository<Customer>>();
            const int productId = 23;
            _product = Stub<Product>();
            var productRepository = Stub<IRepository<Product>>().Stubs(x => x.GetById(productId)).Returns(_product);
            _customer = Mock<Customer>();
            var customerFactory = Stub<ICustomerFactory>().Stubs(x => x.Create()).Returns(_customer);
            var handler = new AddProductCommandHandler(_customerRepository, productRepository, customerFactory);

            handler.Execute(new AddProductCommand
                                {
                                    CustomerId = default(int),
                                    ProductId = productId,
                                    Count = Count
                                });
        }

        [Test]
        public void add_product_to_basket_is_called_on_customer()
        {
            _customer.AssertWasCalled(x => x.AddProductToBasket(_product, Count));
        }

        [Test]
        public void new_customer_is_saved()
        {
            _customerRepository.AssertWasCalled(x => x.Save(_customer));
        }    
    }   

The second one is for an existing customer:

    [TestFixture]
    public class when_handling_add_product_to_basket_command_for_existing_customer : BaseTest
    {
        private const int Count = 34;
        private Customer _customer;
        private Product _product;

        [SetUp]
        public void Context()
        {
            const int customerId = 45;
            _customer = Mock<Customer>();
            var customerRepository = Stub<IRepository<Customer>>().Stubs(x => x.GetById(customerId)).Returns(_customer);
            const int productId = 23;
            _product = Stub<Product>();
            var productRepository = Stub<IRepository<Product>>().Stubs(x => x.GetById(productId)).Returns(_product);
            var handler = new AddProductCommandHandler(customerRepository, productRepository, null);

            handler.Execute(new AddProductCommand
                                {
                                    CustomerId = customerId,
                                    ProductId = productId,
                                    Count = Count
                                });
        }

        [Test]
        public void add_product_to_basket_is_called_on_customer()
        {
            _customer.AssertWasCalled(x => x.AddProductToBasket(_product, Count));
        }
    }

Make these tests fail first. Then implement the command handler:

    public class AddProductCommandHandler : BaseCommandHandler<AddProductCommand>
    {
        private readonly IRepository<Customer> _customerRepository;
        private readonly IRepository<Product> _productRepository;
        private readonly ICustomerFactory _customerFactory;

        public AddProductCommandHandler(
            IRepository<Customer> customerRepository,
            IRepository<Product> productRepository,
            ICustomerFactory customerFactory)
        {
            _customerRepository = customerRepository;
            _productRepository = productRepository;
            _customerFactory = customerFactory;
        }

        public override void Execute(AddProductCommand command)
        {
            var isNewCustomer = command.CustomerId == default(int);
            var customer = isNewCustomer
                               ? _customerFactory.Create()
                               : _customerRepository.GetById(command.CustomerId);

            var product = _productRepository.GetById(command.ProductId);               
            
            customer.AddProductToBasket(product, command.Count);
            
            if (isNewCustomer) _customerRepository.Save(customer);
        }
    }

Tests should be passing. In the same way, implement other commands: `UpdateProductCountInBasketCommand`, `SetDeliveryAddressCommand` and `PlaceOrderCommand`.

All commands needed so far are implemented, we can move to queries. 

# <a id="queries"></a>Queries
So far we need two queries: 

1. Get products
2. Get basket items

Applying CQRS pattern ensures that implementation of commands and queries are independent. Commands are implemented via domain layer, queries can be implemented in whatever way is suitable for the project, with one common thing - data are delivered in a DTO (data transfer object). There are couple of NHibernate options how to implement queries:

* reuse domain entities for NHibernate querying via [QueryOver](http://nhforge.org/blogs/nhibernate/archive/2009/12/17/queryover-in-nh-3-0.aspx) and map data from entities into dtos. Unfortunately this option involves sometimes cumbersome joining in query over syntax, and sometimes it is not possible to formulate a query in the most efficient way
* map a dto directly into a database view and hide the SQL complexity in the database view; this option has the advantage that you can write arbitrary SQL query in the database view, but it needs to be written manually; an integration test for the query will ensure that the database view SQL is tested

We are going to implement the latter option - mapping dtos directly into database views. Btw this option allows later converting database views into tables with flattened data to improve performance if needed.

Add a new class library project Eshop.Queries into the solution, reference CoreDdd, add new classes `ProductsQuery` implementing `IQuery` and `ProductsQueryHandler` derived from `BaseQueryOverHandler<ProductsQuery>`:

    public class ProductsQuery : IQuery
    {
    }

    public class ProductsQueryHandler : BaseQueryOverHandler<ProductsQuery>
    {
        public override IQueryOver GetQueryOver<TResult>(ProductsQuery message)
        {
            return null;
        }
    }

We will have integration tests for query handlers as unit testing NHibernate's quering subsystem doesn't make much sense. In the query test we will persist domain aggregate root entities, and will read back dtos. We will place all dtos into standalone project. Create a new class library project called Eshop.Dtos, add a new class `ProductDto` derived from `Dto`:

    public class ProductDto : Dto
    {
        public int Id { get; set; }
        public string Name { get; set; }
    }

Virtual keyword is not needed for dtos properties as lazy loading is disabled for them. So far `Product` entity didn't have any properties except `Id`. For the sake of the integration test, add `Name` property into the entity:

    public class Product : Entity, IAggregateRoot
    {        
        public virtual string Name { get; protected internal set; }
    }

Add folder Database/Queries into Eshop.IntegrationTests and add a new testfixture `when_querying_for_products`:

    [TestFixture]
    public class when_querying_for_products : BaseEshopSimplePersistenceTest
    {
        private IEnumerable<ProductDto> _results;
        private const string ProductOneName = "product one name";
        private const string ProductTwoName = "product two name";

        protected override void PersistenceContext()
        {
            var productOne = new Product { Name = ProductOneName};
            var productTwo = new Product { Name = ProductTwoName };
            Save(productOne, productTwo);
        }

        protected override void PersistenceQuery()
        {
            var handler = new ProductsQueryHandler();
            _results = handler.Execute<ProductDto>(new ProductsQuery());
        }

        [Test]
        public void product_dto_correctly_retrieved()
        {
            _results.Count().ShouldBe(2);
            _results.Any(x => x.Name == ProductOneName).ShouldBe(true);
            _results.Any(x => x.Name == ProductTwoName).ShouldBe(true);
        }
    }

Implement GetProductsQueryHandler:

    public class ProductsQueryHandler : BaseQueryOverHandler<ProductsQuery>
    {
        public override IQueryOver GetQueryOver<TResult>(ProductsQuery message)
        {
            return Session.QueryOver<ProductDto>();
        }
    }

Before we can run the test, we need to allow database dto mapping as so far NHibernate is mapping only entities. Modify `UnitOfWorkInitializer`:

        public static INhibernateConfigurator GetNhibernateConfigurator(bool mapDtos = true)
        {
            var assembliesToMap = new List<Assembly> { typeof(Customer).Assembly };
            if (mapDtos) assembliesToMap.Add(typeof(ProductDto).Assembly);
            return new NhibernateConfigurator(assembliesToMap.ToArray(), new[] {typeof (Entity<>) }, new Type[0], true, null);
        }

Modify `EshopDatabaseSchemaGenerator` to not map dtos as dtos will be represented by manually written database views:

        protected override INhibernateConfigurator GetNhibernateConfigurator()
        {
            return UnitOfWorkInitializer.GetNhibernateConfigurator(false);
        }

If we run the query handler test now, it's gonna complain about unmapped Id for `ProductDto`. We need to add custom mapping:

    public class ProductDtoAutoMap : IAutoMappingOverride<ProductDto>
    {
        public void Override(AutoMapping<ProductDto> mapping)
        {
            mapping.Id(x => x.Id);
        }
    }

When we run the test now it should be failing on missing ProductDto database view. Create ProductDto database view (SQL server syntax):

    IF OBJECT_ID('ProductDto') IS NOT NULL 
    DROP VIEW ProductDto
    GO

    CREATE VIEW ProductDto
    AS
    select
        Id
        , Name
    from Product
    
    go

Integration test should be passing now. Implement the second `BasketItemsQuery` returning data in `BasketItemDto`. Test:

    [TestFixture]
    public class when_querying_for_basket_items : BaseEshopSimplePersistenceTest
    {
        private IEnumerable<BasketItemDto> _results;
        private Customer _customer;
        private Product _productOne;
        private Product _productTwo;
        private const string ProductOneName = "product one name";
        private const string ProductTwoName = "product two name";
        private const int ProductOneCount = 23;
        private const int ProductTwoCount = 24;

        protected override void PersistenceContext()
        {
            _productOne = new Product { Name = ProductOneName};
            _productTwo = new Product { Name = ProductTwoName };
            _customer = new Customer();
            _customer.BasketItems.AsSet().AddAll(new[]
                                                    {
                                                        new BasketItem(_customer, _productOne, ProductOneCount),
                                                        new BasketItem(_customer, _productTwo, ProductTwoCount),
                                                    });
            var anotherCustomer = new Customer();
            anotherCustomer.BasketItems.AsSet().AddAll(new[] { new BasketItem(anotherCustomer, _productOne, ProductOneCount) });

            Save(_productOne, _productTwo, _customer, anotherCustomer);
        }

        protected override void PersistenceQuery()
        {
            var handler = new BasketItemsQueryHandler();
            _results = handler.Execute<BasketItemDto>(new BasketItemsQuery { CustomerId = _customer.Id });
        }

        [Test]
        public void basket_item_dtos_correctly_retrieved()
        {
            _results.Count().ShouldBe(2);

            var result = _results.First();
            result.CustomerId.ShouldBe(_customer.Id);
            result.ProductId.ShouldBe(_productOne.Id);
            result.ProductName.ShouldBe(ProductOneName);
            result.Count.ShouldBe(ProductOneCount);
            
            result = _results.Last();
            result.CustomerId.ShouldBe(_customer.Id);
            result.ProductId.ShouldBe(_productTwo.Id);
            result.ProductName.ShouldBe(ProductTwoName);
            result.Count.ShouldBe(ProductTwoCount);
        }
    }

Query handler implementation:

    public class BasketItemsQueryHandler : BaseQueryOverHandler<BasketItemsQuery>
    {
        public override IQueryOver GetQueryOver<TResult>(BasketItemsQuery query)
        {
            return Session.QueryOver<BasketItemDto>().Where(x => x.CustomerId == query.CustomerId);
        }
    }

Database view (SQL server syntax):

    IF OBJECT_ID('BasketItemDto') IS NOT NULL 
    DROP VIEW BasketItemDto
    GO

    CREATE VIEW BasketItemDto
    AS
    select
        bi.Id
        , bi.CustomerId
        , bi.ProductId
        , p.Name            as ProductName
        , bi.[Count]
    from BasketItem bi
    join Product p ON p.Id = bi.ProductId
    
    go

Now, we have two ad-hoc database views in the db which we need to save into the solution. We will create a new folder in the solution folder on a disk called *Eshop.Database*, and create a new folder *Views* in it. Create files 0010-ProductDto.sql and 0020-BasketItemDto.sql and paste the database view SQL into them. We will create a script to automatically create an application and a test database. The number in the database view file name defines an order of the view being created when running these scripts. Update schema generator app to generate the database create sql script into Eshop.Database folder:

    var schemaGenerator = new EshopDatabaseSchemaGenerator(@"..\..\..\Eshop.Database\eshop_generated_database_schema.sql");

There are couple of script files to create an application and a test database in [Eshop.Database](http://code.google.com/p/eshop-coreddd/source/browse/#svn%2Ftrunk%2FEshop.Database) folder - `create_Eshop_db.bat` and `create_EshopTest_db.bat`. These are currently SQL server only, you might want to modify these for your database.