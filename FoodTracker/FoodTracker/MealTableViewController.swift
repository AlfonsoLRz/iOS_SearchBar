//
//  MealTableViewController.swift
//  FoodTracker
//
//  Created by Jane Appleseed on 11/15/16.
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import UIKit
import os.log

@available(iOS 11.0, *)
class MealTableViewController: UITableViewController, UISearchResultsUpdating, UISearchBarDelegate {
    
    //MARK: Properties
    
    var filteredMeals = [Meal]()        // Meals obtained from the search process.
    var meals = [Meal]()
    let searchController = UISearchController(searchResultsController: nil)     // The view that will display the results from the search will be this one and not other (nil).

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Use the edit button item provided by the table view controller.
        navigationItem.leftBarButtonItem = editButtonItem
        
        // Set up search controller.
        searchController.searchResultsUpdater = self    // Who is the responsible of updating the displayed results?
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false   // Otherwise the navigation bar disappear so we cannot edit the table view.
        searchController.searchBar.placeholder = "Search food"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false      // Necessary to show the search bar from the start.
        definesPresentationContext = true   // Search bar disappears when another view is displayed.
        
        // Scopes.
        searchController.searchBar.scopeButtonTitles = ["Name", "Rating"]
        searchController.searchBar.delegate = self
        
        // Load any saved meals, otherwise load sample data.
        if let savedMeals = loadMeals() {
            meals += savedMeals
        } else {
            // Load the sample data.
            loadSampleMeals()
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            return filteredMeals.count
        }
        
        return meals.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "MealTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? MealTableViewCell  else {
            fatalError("The dequeued cell is not an instance of MealTableViewCell.")
        }
        
        // Fetches the appropriate meal for the data source layout.
        let meal : Meal
        if isFiltering() {
            meal = filteredMeals[indexPath.row]
        } else {
            meal = meals[indexPath.row]
        }
        
        cell.nameLabel.text = meal.name
        cell.photoImageView.image = meal.photo
        cell.ratingControl.rating = meal.rating
        
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            if isFiltering() {
                filteredMeals.remove(at: indexPath.row)
                
                if let index = meals.index(of: filteredMeals[indexPath.row]) {
                    meals.remove(at: index)
                }
            } else {
                meals.remove(at: indexPath.row)
            }
            saveMeals()
            
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */
    
    //MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            
        case "AddItem":
            os_log("Adding a new meal.", log: OSLog.default, type: .debug)
            
        case "ShowDetail":
            guard let mealDetailViewController = segue.destination as? MealViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedMealCell = sender as? MealTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedMealCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedMeal : Meal
            if isFiltering() {
                selectedMeal = filteredMeals[indexPath.row]
            } else {
                selectedMeal = meals[indexPath.row]
            }
            mealDetailViewController.meal = selectedMeal
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    //MARK: UISearchResultsUpdating Delegate
    
    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        let scope = searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex]
        filterContentForSearchText(searchController.searchBar.text!, scope: scope)
    }
    
    //MARK: Search Bar Delegate
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        filterContentForSearchText(searchBar.text!, scope: searchBar.scopeButtonTitles![selectedScope])
    }
    
    //MARK: Actions
    
    @IBAction func unwindToMealList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? MealViewController, let meal = sourceViewController.meal {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                var removeRow = false
                
                // Update an existing meal. The meal comes from a filtered table or not?
                if isFiltering() {
                    if let index = meals.index(of: filteredMeals[selectedIndexPath.row]) {
                        meals[index] = meal
                        
                        if !mealMatchesSearch(meal: meal, searchText: searchController.searchBar.text!) {
                            filteredMeals.remove(at: selectedIndexPath.row)
                            removeRow = true
                        }
                    }
                } else {
                    meals[selectedIndexPath.row] = meal
                }
                
                if !removeRow {
                    tableView.reloadRows(at: [selectedIndexPath], with: .none)
                }
            }
            else {
                // Add a new meal.
                var newIndexPath : IndexPath?
                if isFiltering() && mealMatchesSearch(meal: meal, searchText: searchController.searchBar.text!) {
                    newIndexPath = IndexPath(row: filteredMeals.count, section: 0)
                    filteredMeals.append(meal)
                } else if !isFiltering(){
                    newIndexPath = IndexPath(row: meals.count, section: 0)
                }
                
                meals.append(meal)
                if let indexPath = newIndexPath {
                    tableView.insertRows(at: [indexPath], with: .automatic)
                }
            }
            
            // Save the meals.
            saveMeals()
        }
    }
    
    //MARK: Private Methods
    
    private func loadSampleMeals() {
        
        let photo1 = UIImage(named: "meal1")
        let photo2 = UIImage(named: "meal2")
        let photo3 = UIImage(named: "meal3")

        guard let meal1 = Meal(name: "Caprese Salad", photo: photo1, rating: 4) else {
            fatalError("Unable to instantiate meal1")
        }

        guard let meal2 = Meal(name: "Chicken and Potatoes", photo: photo2, rating: 5) else {
            fatalError("Unable to instantiate meal2")
        }

        guard let meal3 = Meal(name: "Pasta with Meatballs", photo: photo3, rating: 3) else {
            fatalError("Unable to instantiate meal2")
        }

        meals += [meal1, meal2, meal3]
    }
    
    private func saveMeals() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(meals, toFile: Meal.ArchiveURL.path)
        if isSuccessfulSave {
            os_log("Meals successfully saved.", log: OSLog.default, type: .debug)
        } else {
            os_log("Failed to save meals...", log: OSLog.default, type: .error)
        }
    }
    
    private func loadMeals() -> [Meal]?  {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Meal.ArchiveURL.path) as? [Meal]
    }
    
    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    private func mealMatchesSearch(meal: Meal, searchText: String) -> Bool {
        let scope = searchController.searchBar.scopeButtonTitles![searchController.searchBar.selectedScopeButtonIndex]
        
        if  scope == "Name" {
            return meal.name.lowercased().contains(searchText.lowercased())
        } else if scope == "Rating" {
            return String(meal.rating).contains(searchText)
        } else {
            fatalError("Recevied unknown scope: \(scope)")
        }
    }
    
    private func filterContentForSearchText(_ searchText: String, scope: String = "Name") {
        filteredMeals = meals.filter({(meal: Meal) -> Bool in
            if scope == "Name" {
                return meal.name.lowercased().contains(searchText.lowercased())
            } else if scope == "Rating" {
                return searchText == String(meal.rating)
            } else {
                fatalError("Received unknown scope: \(scope)")
            }
        })
            
        tableView.reloadData()
    }
}
