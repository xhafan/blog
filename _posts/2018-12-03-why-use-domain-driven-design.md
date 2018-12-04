---
layout: post
title: Why use domain-driven design (DDD)?
published: false
---
Posted By [Martin Havlišta]({{ site.baseurl }}/about.html)

### A short rant about why domain-driven design (DDD) is good.
<!--more-->

In my opinion the domain-driven design (DDD) allows to express the business logic/domain behaviour in the code in the clearest possible object oriented form. The domain is modelled using domain entities (object oriented classes) within one [domain/business logic layer](https://martinfowler.com/bliki/PresentationDomainDataLayering.html), which knows nothing about the database persistence (persistence layer) and the user interface (presentation layer). The domain entities have a rich behaviour like calculations and validations implemented in them. The domain entities are not bags of data properties without any behaviour (an anti-pattern called [anemic domain model](https://www.martinfowler.com/bliki/AnemicDomainModel.html)). When using DDD, you first think about the behaviour - what does it do. You first implement the behaviour - methods doing something useful. 

Another way to design an application is a database driven design - first designing the database tables with fields, and then implementing the domain entities which map it's data properties into the database table fields, and which also contain the database persistence code (a pattern also known as [Active Record](https://www.martinfowler.com/eaaCatalog/activeRecord.html)). But, because the domain entity code contains the database persistence code, it makes the business logic/domain behaviour implementation less clear.

DDD is suitable for larger projects with a complex domain behaviour, and less suitable for projects without rich behaviour (e.g. projects which just edit a data). Projects which would benefit from DDD would take couple of months/years to develop, would be continuously developed, maintained, and amended as per new business requirements. For such projects, the code in two years time could be quite different from the code when the project was started. Somewhere in the middle of the implementation, when the team gain more domain knowledge, they might realize the initial domain model is not sufficient, and that they need to refactor the code into a slightly different domain model. Refactoring the business logic/domain behaviour code, which is a pure object oriented code, contained within one domain/business logic layer, is easier than refactoring the business logic which is scattered all over the place within the presentation and the persistence layer. 

Start using DDD with [Chicago style test-driven development](https://softwareengineering.stackexchange.com/questions/123627/what-are-the-london-and-chicago-schools-of-tdd) (TDD), and the project you are working on will never become one of those unmaintainable slowly dying projects. 

For a great explanation of DDD, please refer to this [Stack Overflow answer](https://stackoverflow.com/a/1222488/379279). 
For diving deep into DDD I recommend [Eric Evan's book](https://amzn.to/2E9dRAC).
For a domain-driven design and a database driven design comparison, please refer to this [Stack Overflow answer](https://stackoverflow.com/a/308647/379279).