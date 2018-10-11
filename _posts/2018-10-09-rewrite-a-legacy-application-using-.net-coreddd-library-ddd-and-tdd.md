---
layout: post
title: Rewrite a legacy application using .NET, CoreDdd library, DDD and TDD
published: false
---

When considering rewriting a fairly big legacy application, written in now outdated frameworks (e.g. ASP.NET Web Forms), using legacy ways of implementing a business logic (e.g. a business logic encoded in database stored procedures), which everybody is afraid to modify, there are couple of options for the rewrite:

1. Incrementally rewrite problematic parts, adding a new code into the same application. The legacy code and the new code would use the same database. Once the new implementation is ready, switch it on, and disable the old implementation. This approach enables not touching the legacy code, only adding a new code, which would not be reusing the legacy code at all. For example, it is possible to [add ASP.NET MVC into ASP.NET Web Forms](https://stackoverflow.com/questions/2203411/combine-asp-net-mvc-with-webforms) application, but it would not be possible to rewrite the application in ASP.NET Core MVC.
2. Incrementally rewrite problematic parts as a new application, where both applications use the same database instance. This approach allows rewriting the application in a modern framework (e.g. ASP.NET Core MVC), and running both projects in production side by side. Once the new implementation is ready, switch it on in the new application, and disable it from the legacy application. 
3. Complete application rewrite, with a new database structure, with a big bang deployment and a database migration script, with no easy way to go back when things go wrong. It takes longest time to develop, as you have to rewrite most of the features before the new application can replace the legacy one.

I personally prefer the option 2 for the following reasons:

- allows [agile software development](https://en.wikipedia.org/wiki/Agile_software_development) - a delivery of new features is regular, with a feedback from users
- the business can prioritize which features will be delivered first 
- no unrealistic fixed distant delivery deadline as with option 3

Sometimes option 1 is fine as well, as long as the framework used on the legacy project is upgradeable to a more modern (preferably latest) version (e.g. .NET 2 -> .NET 4.x). Project rewrites using options 3 I've seen mostly failed, and were destined to be slowly abandoned or rewritten yet again.

If you decided to rewrite your legacy application using [DDD](https://stackoverflow.com/questions/1222392/can-someone-explain-domain-driven-design-ddd-in-plain-english-please) because the business domain is too complex, [CoreDdd](https://github.com/xhafan/coreddd/wiki) .NET library can help with the DDD infrastructure for your project. It supports .NET Core 2 and higher and .NET framework 4 and higher. To learn more about CoreDdd, please refer to the CoreDdd  [documentation](https://github.com/xhafan/coreddd/wiki) and [code samples](https://github.com/xhafan/coreddd-sample).

[implement example ASP.NET Web Forms app, executing some SP doing some crazy stuff with 2-3 tables, and show an sample rewrite over the same database using CoreDdd, DDD, **chicago TDD**] 

[Performance - publishing messages to bus]
   
[docker hub - continuous deployment]

[mention adding CI - e.g. appveyor - when multiple devs working on the project]

[add a new CoreDdd wiki page about persistence unit tests]

Steps:
1. Rewrite the project by adding code inside the project - add CoreDdd, unit tests, persistence tests
2. Add a new ASP.NET Core project and re-use code added in step 1.
3. Add docker support, deploy alpine linux image of the project to docker hub
4. Run the app inside docker linux, docker pull to do an application update   