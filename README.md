## active\_record\_extensions

Collection of minor extensions to ActiveRecord which just makes life easier.



### ClassMethods


* `strictly_belongs_to(table_name, options = {}) `

      Encapsulates pattern for delegating to and validating `belongs_to`
    associations so that you can write
    
        class Comment < ActiveRecord::Base
          strictly_belongs_to :post, :delegating => [ :subdomain ]
        end
    
    instead of
    
        class Comment < ActiveRecord::Base
          belongs_to :post
          validates_presence_of :post_id
          delegate :subdomain, :to => :post
        end
    
    Generates proper validation for polymorphic models, passes through
    `:message, :on, :if, :unless` options to `validates_presence_of`.

* `my_quote_columns(*column_names) `

      Quotes passed columns prepending properly quoted table name 
    (useful for joins of other cases where columns must be fully qualified).

* `validates_url_format_of(*attr_names) `

      Validates that the attribute is the proper URL.

* `validates_email_format_of(*attr_names) `

      Validates that the attribute is a proper email.

* `validates_subdomain_format_of(attr_name, options = {}) `

      Validates that the attribute can be used as the name of the subdomain.

* `random`

      Returns random record.
    The implementation isn't RDBMS vendor specific.


### InstanceMethods


* `smart_clone(changing_attributes = {}) `

      Clones the model resetting `created_at/updated_at` attributes, and
    setting attributes from `changing_attributes` on cloned model.

* `to_ostruct_exposing(*exposed_methods_and_initialize_hashes) `

      Constructs OpenStruct based on the record.
    Names of methods which will be carried along to resulting OpenStruct can be passed
    and also initialization hash as for normal OpenStruct constructor.

* `to_hash_exposing(*exposed_methods_and_initialize_hashes) `

      Constructs OpenStruct based on the record.
    Names of methods which will be carried along to resulting OpenStruct can be passed
    and also initialization hash as for normal OpenStruct constructor.

* `short_inspect`

      Returns brief information about model (id or new_record) and truncated
    `name/title` attribute when such attribute is present.
    Useful in log messages.

* `hit!`

      Registers object view (when object has :views attribute).

* `inspect_errors`

      Returns all found validation errors + the result of `inspect` so that you
    from which model these errors came. Again can be useful in logging.

* `valid!`

      Raises exception if record is invalid.


### ActiveRecordExtensions::RecordInvalid

Replaces Rails default `ActiveRecord::RecordInvalid` exception.
When `save!` or `create!` is called for model which can't be validated
`ActiveRecord::RecordInvalid` exception is raised.
The message of this exception includes the description of validation errors
but doesn't say anything about the model for which the validation failed.
This `ActiveRecord::RecordInvalid` implementation adds this information to
the exception message. Useful in logging, batch processing, etc.


Hats off to [Loren Segal](http://gnuu.org/) for his awesome
[YARD](http://yardoc.org/) tool which is used to generate this README file from
the code directly.

