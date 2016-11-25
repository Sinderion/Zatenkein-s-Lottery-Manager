using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace CompileToSpreadsheet
{
    class Program
    {
        static void Main(string[] args)
        {
            var wowDirectories = GetWoWDirectories();
            string activeWoWDirectory = PromptWoWDirectory(wowDirectories);
            var wowAccounts = GetWoWAccounts(activeWoWDirectory);
            string activeWoWAccount = PromptWoWAccount(wowAccounts);
            
        }

        public static List<string> GetWoWDirectories()
        {
            var output = new List<string>();

            foreach(DriveInfo drive in DriveInfo.GetDrives())
            {
                output.AddRange(
                    Directory.GetDirectories(
                        drive.Name,
                        "World of Warcraft",
                        SearchOption.AllDirectories
                    )
                );
            }
            
            return output;
        }

        public static List<string> GetWoWAccounts(string wowDirectory)
        {
            var output = new List<string>();

            output.AddRange(
                Directory.GetDirectories(
                    Path.Combine(
                        wowDirectory,
                        "WTF",
                        "ACCOUNT"
                    )
                )
            );

            return output;
        }

        public static bool AccountHasZLM(string account)
        {
            return File.Exists(
                Path.Combine(
                    account,
                    "SavedVariables",
                    "Zatenkein's Lottery Manager.lua"
                )  
            );
        }

        public static string PromptWoWDirectory(List<string> directories)
        {
            if (directories.Count > 1)
            {
                var selection = 0;
                do
                {
                    Console.WriteLine("Please select the WoW Installation you would like to use.");
                    for (var i = 0; i < directories.Count; i++)
                    {
                        Console.WriteLine((i + 1) + ". " + directories[i]);
                    }
                    int.TryParse(Console.ReadLine(), out selection);
                } while (selection <= 0);
                return directories[selection - 1];
            }
            else if(directories.Count > 0)
            {
                return directories[0];
            }
            else
            {
                Console.WriteLine("Could not find a WoW installation.");
                throw new Exception("Could not find a WoW installation.");
            }
        }

        public static string PromptWoWAccount(List<string> accountList)
        {
            if (accountList.Count > 0)
            {
                var accounts = accountList.Where(a => AccountHasZLM(a)).ToList();
                if (accounts.Count > 1)
                {
                    var selection = 0;
                    do
                    {
                        Console.WriteLine("Please select a WoW Account from which you would like to load the saved variables.");
                        for (var i = 0; i < accounts.Count; i++)
                        {
                            Console.WriteLine((i + 1) + ". " + accounts[i]);
                        }
                        int.TryParse(Console.ReadLine(), out selection);
                    } while (selection <= 0);
                    return accounts[selection - 1];
                }
                else if (accounts.Count > 0)
                {
                    return accounts[0];
                }
            }
            Console.WriteLine("Could not locate any WoW accounts within this WoW directory that have ZLM.");
            throw new Exception("Could not locate any WoW accounts within this WoW directory that have ZLM.");

        }

        public static void ParseToExcel(string account)
        {
            
        }
    }   
}
