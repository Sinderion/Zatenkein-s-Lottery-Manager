using System;
using System.Collections.Generic;
using System.Linq;
using System.IO;
using LsonLib;
using Microsoft.Office.Interop.Excel;
using System.Reflection;
using System.Configuration;
using System.Net;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CompileToSpreadsheet
{
    class Program
    {

        static void Main(string[] args)
        {
            if (!File.Exists("SavedSettings.txt"))
            {
                Console.WriteLine("Please paste the file path of the ZLM saved variables file you wish to parse.");
                string ZLMPath = Console.ReadLine();
                Console.WriteLine("Please paste the directory path where you would like to paste the file.");
                string ReportPath = Console.ReadLine();
                File.WriteAllLines("SavedSettings.txt", new string[] { ZLMPath,  ReportPath});
            }
            try
            {
                string[] settings = File.ReadAllLines("SavedSettings.txt");
                ParseToExcel(settings);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Console.ReadKey();
            }
            
        }

        public static string GetSavedVariables(string path)
        {
            if (File.Exists(path))
            {
                return File.ReadAllText(path);
            }
            return "";
        }

        public static void ParseToExcel(string[] settings)
        {
            string savedVariables = GetSavedVariables(settings[0]);
            var lson = LsonVars.Parse(savedVariables);
            var donators = lson["ZLM_Donators"];

            Application oXL;
            _Workbook oWB;
            _Worksheet oSheet;

            oXL = new Application();
            oXL.Visible = true;

            oWB = (_Workbook)(oXL.Workbooks.Add(Missing.Value));
            oSheet = (_Worksheet)oWB.ActiveSheet;
            oSheet.Name = "Donations";

            oSheet.get_Range("A1").Value2 = "Character";
            oSheet.get_Range("B1").Value2 = "Item";
            oSheet.get_Range("C1").Value2 = "Quantity";

            oSheet.get_Range("O1").Value2 = "Name";
            oSheet.get_Range("P1").Value2 = "Total Points";

            try
            {
                WriteMaterialsTable(oSheet);
                var row = 1;
                var donorRow = 1;
                foreach (var key in donators.Keys)
                {
                    donorRow += 1;
                    var donator = donators[key];
                    var name = donator["name"].GetStringLenientSafe() ?? "NAME UNKNOWN";
                    var donations = donator["donations"];

                    oSheet.get_Range("O" + donorRow).Value2 = name;
                    oSheet.get_Range("P" + donorRow).Value2 = "=SUMIF($A$2:$A$1000,$O" + donorRow + ",$D$2:$D$1000)";

                    foreach (var donationKey in donations.Keys)
                    {
                        row += 1;
                        var donation = donations[donationKey];
                        oSheet.get_Range("A" + row).Value2 = name;
                        oSheet.get_Range("B" + row).Value2 = donation["item"].GetStringLenientSafe() ?? "NO ITEM FOUND";
                        oSheet.get_Range("C" + row).Value2 = donation["quantity"].GetIntLenientSafe().HasValue ? donation["quantity"].GetIntLenientSafe().Value : 0;
                        oSheet.get_Range("D" + row).Value2 = "=VLOOKUP($B2,$F$2:$M$29,4,FALSE)*C" + row;
                    }
                }
            }
            catch(Exception ex)
            {
                throw ex;
            }
            try
            {
                oWB.SaveAs(Path.Combine(settings[1],"TCAccounting_" + DateTime.Now.AddHours(-1).ToString("hh-mm-ss-MM-dd-yyyy")));
            }
            catch { }
        }

        public static void WriteMaterialsTable(_Worksheet sheet)
        {
            List<string> ingredients = ConfigurationManager.AppSettings["ZLM.Ingredients"].Split(',').ToList();
            List<string> hotItems = ConfigurationManager.AppSettings["ZLM.HotItems"].Split(',').ToList();
            var ingredientRow = 1;

            sheet.get_Range("F1").Value2 = "Item";
            sheet.get_Range("G1").Value2 = "Base Entries";
            sheet.get_Range("H1").Value2 = "Hot Items";
            sheet.get_Range("I1").Value2 = "Entries Per Item";
            sheet.get_Range("J1").Value2 = "Recieved";
            sheet.get_Range("K1").Value2 = "Entries Awarded for Item";
            sheet.get_Range("L1").Value2 = "Item Value";
            sheet.get_Range("M1").Value2 = "Total Value";

            foreach(string ingredient in ingredients)
            {
                var ingredientId = ConfigurationManager.AppSettings["ZLM." + ingredient + ".Id"];
                ingredientRow += 1;
                sheet.get_Range("F" + ingredientRow).Value2 = ingredient;
                sheet.get_Range("G" + ingredientRow).Value2 = ConfigurationManager.AppSettings["ZLM." + ingredient];
                sheet.get_Range("H" + ingredientRow).Value2 = hotItems.Contains(ingredient) ? 1 : 0;
                sheet.get_Range("I" + ingredientRow).Value2 = "=G" + ingredientRow + "*(H" + ingredientRow + "+1)";
                sheet.get_Range("J" + ingredientRow).Value2 = "=SUMIF($B$2:$B$1004,$F" + ingredientRow + ",$C$2:$C$1004)";
                sheet.get_Range("K" + ingredientRow).Value2 = "=J" + ingredientRow + "*I" + ingredientRow;
                sheet.get_Range("L" + ingredientRow).Value2 = GetItemPrice(ingredientId);
                sheet.get_Range("M" + ingredientRow).Value2 = "=L" + ingredientRow + "*J" + ingredientRow;
            }
            ingredientRow += 1;
            sheet.get_Range("F" + ingredientRow).Value2 = "Total";
            sheet.get_Range("K" + ingredientRow).Value2 = "=SUM(K2:K" + (ingredientRow - 1) + ")";
            sheet.get_Range("M" + ingredientRow).Value2 = "=SUM(M2:M" + (ingredientRow - 1) + ")";
        }

        static object auctionData;
        public static decimal GetItemPrice(string item)
        {
            if(auctionData == null)
            {
                PopulateAuctionData();
            }
            var items = from auction in ((JArray)auctionData)
                        where (string)auction["item"] == item && (decimal)auction["buyout"] != 0
                        select (decimal)auction["buyout"] / 10000 / (decimal)auction["quantity"];
            return items.Min();
        }

        public static void PopulateAuctionData()
        {
            var url = "http://auction-api-us.worldofwarcraft.com/auction-data/9a1d3a10e02108f7dc2f0258c0364a40/auctions.json";
            WebRequest req = WebRequest.Create(url);
            var response = req.GetResponse();
            var serializer = new JsonSerializer();
            auctionData = serializer.Deserialize<dynamic>(new JsonTextReader(new StreamReader(response.GetResponseStream()))).auctions;
        }
    }
}