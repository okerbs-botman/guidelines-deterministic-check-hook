using System;
using System.Collections.Generic;
using System.Linq;

namespace Test.Violations
{
    [Table("TEST01")]

    [Title("Test Entity")]
    public class TestViolations : BaseEntity
    {
        // This is a prohibited comment

        private void UseOfVar()
        {
            var list = new List<int>();
        }

        private void RawException()
        {
            throw new Exception("Something went wrong");
        }

        private void DateTimeWithoutKind()
        {
            DateTime dt = new DateTime(2024, 1, 1);
        }

        private void EqualsTrueUsage()
        {
            bool result = collection?.Any() == true;
        }

        private void GetAllFirst()
        {
            ENTITY e = service.GetAll().FirstOrDefault(x => x.Id == 1);
        }

        private void BracelessIf()
        {
            if (condition)
                DoSomething();
        }
    }
}


