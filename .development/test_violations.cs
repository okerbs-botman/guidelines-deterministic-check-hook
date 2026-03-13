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

	private void TabIndented()
        {
            string s = "tabs used above";
        }

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

        private void HardcodedSN()
        {
            if (entity.HABITUAL == "S")
            {
                Process();
            }
        }

        private void FirstLastOnList()
        {
            ENTITY first = list.First();
            ENTITY last = list.Last();
        }

        private void BlockComment()
        {
            /* this is a block comment */
            int x = 1;
        }

        private void RawSqlUsage()
        {
            IQueryable<ROW> rows = uow.ExecuteRawQuery<ROW>(ContextType.Company, "SELECT * FROM T");
        }

        public void PublicMethodFirst()
        {
            DoSomething();
        }

        private void PrivateAfterPublic()
        {
            DoSomethingElse();
        }
    }
}


