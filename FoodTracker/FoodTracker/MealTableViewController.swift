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
    
    var filteredMeals = [Meal]()                                                // Meals obtained from the search process.
    var meals = [Meal]()                                                        // Main array of meals.
    let searchController = UISearchController(searchResultsController: nil)     // The view that will display the results from the search will be this one and not other (nil).

    
    /**
 
     Initializes the search and the scope bar as well as the meal array. Meals are initialized by loading the objects saved in files.
 
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Use the edit button item provided by the table view controller.
        navigationItem.leftBarButtonItem = editButtonItem
        
        // Set up search controller.
        searchController.searchResultsUpdater = self                    // Who is the responsible of updating the displayed results?
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search meal"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false              // Show the search bar from the start.
        definesPresentationContext = true                               // Search bar disappears when another view is displayed.
        
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

    
    //MARK: Table view data source

    /**
     
     Returns the number of sections of the table view.
     
    */
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    
    /**
 
     Returns the number of meals in our section. We'll take this number from two arrays, depending on if there's any active search.
     
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            return filteredMeals.count
        }
        
        return meals.count
    }

    /**
 
     Returns a row from the table view. That cell contains the attributes of the meal: title, image and rating.
     
    */
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
    
    /**
 
     Returns true since a row is always editable.
     
    */
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    /**
 
     Operations on the table view rows. Only delete is allowed.
     
    */
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source,
            if isFiltering() {
                if let index = meals.index(of: filteredMeals[indexPath.row]) {      // We don't know the index at the main array.
                    meals.remove(at: index)
                }
                filteredMeals.remove(at: indexPath.row)
            } else {
                meals.remove(at: indexPath.row)
            }
            saveMeals()
            
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    
    //MARK: Navigation

    /**
 
     Prepatation before segues to MealViewController. It depends on the context, Add or Update meal.
     
    */
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
            
            // Depending on if the search is active or not, we'll take the meal from an specific array.
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
    
    /**
     
     Returns a boolean value that takes into account if there's an active search at this moment.
 
    */
    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
    
    /**
 
     Event received when any update occurs in the search bar.
     
    */
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        let scope = searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex]
        filterContentForSearchText(searchController.searchBar.text!, scope: scope)
    }
    
    
    //MARK: Search Bar Delegate
    
    /**
     
     Search bar filter.
 
    */
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        filterContentForSearchText(searchBar.text!, scope: searchBar.scopeButtonTitles![selectedScope])
    }
    
    
    //MARK: Actions
    
    /**
     
     Unwind segue from MealViewController. Possible events: addition or update.
 
    */
    @IBAction func unwindToMealList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? MealViewController, let meal = sourceViewController.meal {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                var removeRow = false       // If we remove the updated array from filteredMeals we don't have to reload it.
                
                // Update an existing meal. The meal comes from a filtered table or not?
                if isFiltering() {
                    if let index = meals.index(of: filteredMeals[selectedIndexPath.row]) {
                        meals[index] = meal
                        
                        if !mealMatchesSearch(meal: meal, searchText: searchController.searchBar.text!) {   // Un update could make the meal to not match the currently active search.
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
                let newIndexPath = IndexPath(row: meals.count, section: 0)
                
                meals.append(meal)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            
            // Save the meals.
            saveMeals()
        }
    }
    
    
    //MARK: Private Methods
    
    /**
 
     Result of a search. Basically compares the input text and the meal scope (Name of Rating) and reloads the table view data.
 
    */
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
    
    /**
     
     Load meals from the file specified by the class Meal.
 
    */
    private func loadMeals() -> [Meal]?  {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Meal.ArchiveURL.path) as? [Meal]
    }
    
    /**
 
     Sample meals in case there is not any meal saved at the file.
 
    */
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
    
    /**
     
     Returns true if the meal matches a search. That happens if the meal contains the text from the search bar, at its title, or its category.
 
    */
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
    
    /**
     
     Save the meals in the file specified by the class Meal.
 
    */
    private func saveMeals() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(meals, toFile: Meal.ArchiveURL.path)
        if isSuccessfulSave {
            os_log("Meals successfully saved.", log: OSLog.default, type: .debug)
        } else {
            os_log("Failed to save meals...", log: OSLog.default, type: .error)
        }
    }
    
    /**
     
     Returns a boolean value depending on if the search bar is empty.
 
     */
    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
}
