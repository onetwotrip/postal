# Postal

Postal is a complete and fully featured mail server for use by websites & web servers. Think Sendgrid, Mailgun or Postmark but open source and ready for you to run on your own servers. Postal was developed by aTech Media to serve its own mail processing requirements and we have since decided that it should be released as an open source project for the community.

![Screenshot](https://share.adam.ac/17/k4lA5OuPlU.png)

The application has been running in production for us for nearly 6 months and we will be continuing to use it ourselves and support its ongoing development. If you have any questions about getting up and running, just post an issue.

* [Read all documentation](https://github.com/atech/postal/wiki)
* [Quick install guide](https://github.com/atech/postal/wiki/Quick-Install)
* [Installation docs](https://github.com/atech/postal/wiki/Installation)
* [FAQs](https://github.com/atech/postal/wiki/FAQs), [Features](https://github.com/atech/postal/wiki/Features) & [Screenshots](https://github.com/atech/postal/wiki/Screenshots)

# OneTwoTrip editions

Included pull requests:

* [Added ability to use clustered rabbitmq](https://github.com/atech/postal/pull/725)
* [add migration to increase links url size](https://github.com/atech/postal/pull/683)
* [Message database default character set utf8mb4](https://github.com/atech/postal/pull/391)
* [fixes for link conversion](https://github.com/atech/postal/pull/296)
* [Added new error to raw sending API - MissingFromAddress as distinct from UnauthenticatedFromAddress](https://github.com/atech/postal/pull/542)

And custom changes:

* Added special symbols to link conversion: | @ ! and ,
* Added mini_racer gem
* Moved to LetsEncrypt v2
* Split :main queue to :main and :webhooks
* Changed process of link generation
* Disabled IP address checking
* Add force_index on_address for suppressions
* Disabled statistics
* Local named is required (option to set custom DNS server is not provided)
* Deleted counter for database size